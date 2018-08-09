//
//  U2FSetupController.swift
//  Krypton
//
//  Created by Alex Grinman on 5/6/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import JSON
import AVFoundation
import LocalAuthentication

class InstallU2FController:KRBaseController, KRScanDelegate{
    
    @IBOutlet weak var scanView:UIView!
    @IBOutlet weak var permissionView:UIView!
    @IBOutlet weak var installCard:UIView!
    @IBOutlet weak var scanCard:UIView!
    @IBOutlet weak var scanContainer:UIView!

    var scanController:KRScanController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scanController?.canScan = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // by default we set u2f user interaction to off
        Policy.requireUserInteractionU2F = false

        installCard.setBoxShadow()
        scanCard.setBoxShadow()
        
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            == AVAuthorizationStatus.authorized
        {
            addScanner()
            permissionView.isHidden = true
        }
        
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            let message = "Push notifications are used to send website login requests."
            self.askConfirmationIn(title: "Enable Push notifications?", text: message, accept: "Enable", cancel: "Later")
            { (enable) in
                if enable {
                    (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
                    Analytics.postEvent(category: "push", action: "enabled")
                } else {
                    Analytics.postEvent(category: "push", action: "not-enabled")
                }
            }
        }
    }
    
    @IBAction func allowTapped() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { (success) in
            if !success {
                self.showSettings(with: "Camera Access", message: "Please enable camera access by tapping Settings. We need the camera to scan your computer's QR code to pair with it. Pairing enables your computer to ask your phone for web logins.")
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
        sc.view.frame = scanContainer.bounds
        scanContainer.addSubview(sc.view)
        self.addChildViewController(sc)
        sc.didMove(toParentViewController: self)
        
        self.scanController = sc
    }
    
    @IBAction func skipTapped() {
        Onboarding.isActive = false

        self.navigationController?.dismiss(animated: true, completion: {
            MainController.current?.didDismissOnboarding()
        })
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
                self.skipTapped()
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
