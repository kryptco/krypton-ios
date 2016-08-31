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

    var scanViewController:KRScanController?
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
    
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
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
        else if let img = RSUnifiedCodeGenerator.shared.generateCode("testing12testing123testing123testing123testing123testing123testing123testing123testing123testing1233", machineReadableCodeObjectType: AVMetadataObjectTypeQRCode) {
            
            let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: CGSize(width:280, height:280), contentMode: UIViewContentMode.scaleAspectFill)
            self.qrImage = resized
            self.qrImageView.image = resized
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
        return false
    }

}






