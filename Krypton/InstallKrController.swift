//
//  FirstPairController.swift
//  Krypton
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import LocalAuthentication
import CoreBluetooth

class InstallKrController:UIViewController, KRScanDelegate {
    
    @IBOutlet weak var brewButton:UIButton!
    @IBOutlet weak var curlButton:UIButton!
    @IBOutlet weak var npmButton:UIButton!
    @IBOutlet weak var moreButton:UIButton!
    
    @IBOutlet weak var installCard:UIView!
    @IBOutlet weak var scanCard:UIView!

    @IBOutlet weak var installLabel:UILabel!
    @IBOutlet weak var commandView:UIView!
    
    var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
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
        
        Onboarding.isActive = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scanController?.canScan = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        installCard.setBoxShadow()
        scanCard.setBoxShadow()

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
                    (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications {
                        self.askBluetoothPermissionIfNeeded()
                    }
                    Analytics.postEvent(category: "push", action: "enabled")
                } else {
                    Analytics.postEvent(category: "push", action: "not-enabled")
                    self.askBluetoothPermissionIfNeeded()
                }
                
            }
        } else {
            askBluetoothPermissionIfNeeded()
        }
    }
    
    // ask bluetooth peripheral permission
    func askBluetoothPermissionIfNeeded() {
        dispatchMain {
            if !TransportControl.shared.isBluetoothPoweredOn() {
                let _ = CBPeripheralManager()
            }
        }
    }
    
    @IBAction func skipTapped() {    
        self.navigationController?.dismiss(animated: true, completion: {
            MainController.current?.didDismissOnboarding()
        })
    }
    
    //MARK: Install Instructions
    
    @IBAction func brewTapped() {
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.brew.command
        
        Analytics.postEvent(category: "onboard_install", action: "brew")
    }
    
    @IBAction func npmTapped() {
        disableAllInstallButtons()
        
        npmButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.npm.command
        
        Analytics.postEvent(category: "onboard_install", action: "npm")
    }
    
    func setCurlState() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.curl.command
    }
    
    @IBAction func curlTapped() {
        setCurlState()
        
        Analytics.postEvent(category: "onboard_install", action: "curl")
    }
    
    @IBAction func moreTapped() {
        disableAllInstallButtons()
        
        moreButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.more.command
        
        Analytics.postEvent(category: "onboard_install", action: "more")
    }
    
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        npmButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        moreButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
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
        sc.view.frame = scanView.bounds
        scanView.addSubview(sc.view)
        self.addChildViewController(sc)
        sc.didMove(toParentViewController: self)
        
        self.scanController = sc
    }
    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        guard let pairing = try? PairingQR(with: data).pairing else {
            dispatchMain { self.showInvalidPairingQR() }
            return false
        }
        
        let pairingApproval = Resources.Storyboard.Pair.instantiateViewController(withIdentifier: "PairApproveController") as! PairApproveController
        pairingApproval.pairing = pairing
        pairingApproval.scanController = scanController
        pairingApproval.modalPresentationStyle = .overCurrentContext
        pairingApproval.modalTransitionStyle = .crossDissolve
        pairingApproval.didPairSuccessfully = {
            dispatchMain {
                let tutorial = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "KrTutorialController") as! KrTutorialController
                self.navigationController?.pushViewController(tutorial, animated: true)
            }
        }
        
        dispatchMain {
            self.present(pairingApproval, animated: true, completion: nil)
        }
        return true
    }
    
    func showInvalidPairingQR() {
        let invalidQRAlert = UIAlertController(title: "Invalid Code", message: "The QR you scanned is invalid.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        invalidQRAlert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.default, handler: { (_) in
            self.scanController?.canScan = true
        }))
        
        self.present(invalidQRAlert, animated: true, completion: nil)
    }
    

    
}
