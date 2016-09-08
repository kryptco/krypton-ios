//
//  ExchangeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

enum ExchangeState:Int {
    case Scan = 0, Key = 1
}
class ExchangeController: UIViewController, KRScanDelegate {

    var state = ExchangeState.Scan
    
    @IBOutlet weak var qrImageView:UIImageView!
    @IBOutlet weak var blurView:UIView!

    @IBOutlet var scanViewController:KRScanController?
    var qrImage:UIImage?
    
    // stored properties

    @IBOutlet var segmentedControl:UISegmentedControl!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        self.showScanningMode()

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.barTintColor = UIColor.app

        self.qrImage = nil
        self.qrImageView.setBorder(color: UIColor.app, cornerRadius: 20.0, borderWidth: 0)
        
        if self.segmentedControl.selectedSegmentIndex == ExchangeState.Scan.rawValue {
            self.scanViewController?.canScan = true
        }
    }
    
    var shouldShowProfile = true
    override func viewDidAppear(_ animated: Bool) {
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        super.viewDidAppear(animated)
        
        if TARGET_IPHONE_SIMULATOR == 1 && shouldShowProfile {
            shouldShowProfile = false
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanner = segue.destination as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        }
    }

    func showScanningMode() {
        self.state = .Scan
        self.segmentedControl.selectedSegmentIndex = self.state.rawValue

        self.scanViewController?.view.isHidden = false
        self.scanViewController?.canScan = true
        
        UIView.animate(withDuration: 0.3) { () -> Void in
            self.blurView.isHidden = true
        }
    }
    
    func showKeyMode() {
        self.state = .Key
        self.segmentedControl.selectedSegmentIndex = self.state.rawValue
        self.scanViewController?.canScan = false

        if let qr = self.qrImage {
            self.qrImageView.image = qr
        }
        else {
            do {
                let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
                let email = try KeyManager.sharedInstance().getMe().email
                
                let params = ["public_key": publicKey, "email": email]

                
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)
                
                
                if let json = jsonString, let img = RSUnifiedCodeGenerator.shared.generateCode(json, machineReadableCodeObjectType: AVMetadataObjectTypeQRCode) {
                    
                    let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: CGSize(width:280, height:280), contentMode: UIViewContentMode.scaleAspectFill)
                    self.qrImage = resized
                    self.qrImageView.image = resized
                }
                
            } catch (let e) {
                log("error getting keypair: \(e)", LogType.error)
                showWarning(title: "Error loading keypair", body: "\(e)")
            }
            
        }
        
     
        
        UIView.animate(withDuration: 0.3) { () -> Void in
            self.blurView.isHidden = false
        }
    }
    
    
    @IBAction func changeSegmentState(sender:UISegmentedControl) {
        if sender.selectedSegmentIndex == ExchangeState.Scan.rawValue {
            self.showScanningMode()
        } else if sender.selectedSegmentIndex == ExchangeState.Key.rawValue {
            self.showKeyMode()
        }
    }

    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard   let value = data.data(using: String.Encoding.utf8),
                let json = (try? JSONSerialization.jsonObject(with: value, options: JSONSerialization.ReadingOptions.allowFragments)) as? [String:AnyObject]
        else {
            return false
        }
        
        
        if let peer = try? Peer(json: json) {
            PeerManager.sharedInstance().add(peer: peer)
            return true
        } else if let pairing = try? Pairing(json: json) {
            do {
                let session = try Session(pairing: pairing)
                SessionManager.sharedInstance().add(session: session)
            }
            catch let e {
                log("error creating session: \(e)", .error)
                return false
            }
            dispatchAsync {
                API().receive(with: pairing)
            }
            dispatchAfter(delay: 1.0, task: { 
                self.scanViewController?.canScan = true
            })
            return true
        }
        
    
        return false
    }

}






