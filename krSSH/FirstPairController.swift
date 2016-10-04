//
//  FirstPairController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import LocalAuthentication

class FirstPairController:UIViewController, KRScanDelegate {
    
    enum InstallMethod:String {
        case brew = "brew install kryptco/tap/kr"
        case curl = "curl https://krypt.co/kr | sh"
        case apt = "apt-get install kr"
        
    }
    
    @IBOutlet weak var installLabel:UILabel!
    
    @IBOutlet weak var scanView:UIView!
    @IBOutlet weak var permissionView:UIView!

    var firstTime = false

    var scanController:KRScanController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scanController?.canScan = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            == AVAuthorizationStatus.authorized
        {
            addScanner()
            permissionView.isHidden = true
        }
        
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            self.askConfirmationIn(title: "Enable Push notifications?", text: "Push notifications are used to notify you when your private key is used. Push notifications signficiantly improve the app experience.", accept: "Enable", cancel: "Later")
            { (enable) in
                
                if enable {
                    (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
                }
                UserDefaults.standard.set(true, forKey: "did_ask_push")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if
            let animationController = segue.destination as? PairingAnimationController,
            let session = sender as? Session
        {
            animationController.session = session
        }
    }
    
    //MARK: Install Instructions
    
    @IBAction func brewTapped() {
        installLabel.text = InstallMethod.brew.rawValue
    }
    
    @IBAction func aptGetTapped() {
        installLabel.text = InstallMethod.apt.rawValue
    }
    
    @IBAction func curlTapped() {
        installLabel.text = InstallMethod.curl.rawValue
    }
    
    //MARK: Camera
    
    @IBAction func allowTapped() {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { (success) in
            if !success {
                self.showSettings(with: "Camera Access", message: "Please enable camera access by tapping Settings. We need the camera to scan your computer's QR code to pair with it. Pairing enables your computer to ask your phone for SSH logins.")
                return
            }
            
            dispatchMain {
                self.addScanner()
                self.permissionView.isHidden = true
            }
        }
    }
    
    func addScanner() {
        if let sc = self.storyboard?.instantiateViewController(withIdentifier: "KRScanController") as? KRScanController
        {
            sc.delegate = self
            
            sc.willMove(toParentViewController: self)
            self.scanView.addSubview(sc.view)
            self.addChildViewController(sc)
            sc.didMove(toParentViewController: self)
            
            self.scanController = sc
        }

    }
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard   let value = data.data(using: String.Encoding.utf8),
            let json = (try? JSONSerialization.jsonObject(with: value, options: JSONSerialization.ReadingOptions.allowFragments)) as? [String:AnyObject]
            else {
                return false
        }
        
        
        if let pairing = try? Pairing(json: json) {            
            do {
                let session = try Session(pairing: pairing)
                Silo.shared.add(session: session)
                self.performSegue(withIdentifier: "showPairingAnimation", sender: session)
                self.scanController?.canScan = true
                
            } catch (let e) {
                log("error scanning: \(e)", .error)
                self.scanController?.canScan = true
                return false
            }
    
            return true
        }
        
        
        return false
    }
    
}
