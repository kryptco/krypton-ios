//
//  FirstPairController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import LocalAuthentication

class FirstPairController:UIViewController, KRScanDelegate {
    
    @IBOutlet weak var brewButton:UIButton!
    @IBOutlet weak var brewLine:UIView!

    @IBOutlet weak var curlButton:UIButton!
    @IBOutlet weak var curlLine:UIView!

    @IBOutlet weak var npmButton:UIButton!
    @IBOutlet weak var npmLine:UIView!

    @IBOutlet weak var moreButton:UIButton!
    @IBOutlet weak var moreLine:UIView!

    @IBOutlet weak var installLabel:UILabel!
    
    @IBOutlet weak var commandView:UIView!

    
    @IBInspectable var inactiveUploadMethodColor:UIColor = UIColor.lightGray

    @IBOutlet weak var scanView:UIView!
    @IBOutlet weak var permissionView:UIView!

    var firstTime = false

    var scanController:KRScanController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandView.layer.shadowColor = UIColor.black.cgColor
        commandView.layer.shadowOffset = CGSize(width: 0, height: 0)
        commandView.layer.shadowOpacity = 0.175
        commandView.layer.shadowRadius = 3
        commandView.layer.masksToBounds = false
        
        setCurlState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scanController?.canScan = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            == AVAuthorizationStatus.authorized
        {
            addScanner()
            permissionView.isHidden = true
        }
        
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            self.askConfirmationIn(title: "Enable Push notifications?", text: "Push notifications are used to send you SSH login requests that you can approve without opening the app. Push notifications significantly improve the app experience.", accept: "Enable", cancel: "Later")
            { (enable) in
                
                if enable {
                    (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
                    Analytics.postEvent(category: "push", action: "enabled")

                }
                UserDefaults.group?.set(true, forKey: "did_ask_push")
                UserDefaults.group?.synchronize()
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
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        brewLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.brew.command
        
        Analytics.postEvent(category: "onboard_install", action: "brew")
    }
    
    @IBAction func npmTapped() {
        disableAllInstallButtons()
        
        npmButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        npmLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.npm.command
        
        Analytics.postEvent(category: "onboard_install", action: "npm")
    }
    
    func setCurlState() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        curlLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.curl.command
    }
    
    @IBAction func curlTapped() {
        setCurlState()
        
        Analytics.postEvent(category: "onboard_install", action: "curl")
    }
    
    @IBAction func moreTapped() {
        disableAllInstallButtons()
        
        moreButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        moreLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.more.command
        
        Analytics.postEvent(category: "onboard_install", action: "more")
    }
    
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        npmButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        moreButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        
        brewLine.backgroundColor = UIColor.clear
        curlLine.backgroundColor = UIColor.clear
        npmLine.backgroundColor = UIColor.clear
        moreLine.backgroundColor = UIColor.clear
    }


    //MARK: Camera
    
    @IBAction func allowTapped() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { (success) in
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
        let sc = KRScanController()
        
        sc.delegate = self
        sc.willMove(toParentViewController: self)
        sc.view.frame = scanView.frame
        scanView.addSubview(sc.view)
        self.addChildViewController(sc)
        sc.didMove(toParentViewController: self)
        
        self.scanController = sc
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
                
                SessionManager.shared.add(session: session, temporary: true)
                TransportControl.shared.add(session: session, newPairing: true)

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
