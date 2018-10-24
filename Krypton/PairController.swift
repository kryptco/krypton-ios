//
//  ExchangeController.swift
//  Krypton
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class PairController: KRBaseController, KRScanDelegate {
    
    var scanViewController:KRScanController?
    @IBOutlet weak var scanRails:UIImageView!
    @IBOutlet weak var pairCommandHeight:NSLayoutConstraint!

    @IBOutlet weak var instructionBrowserLeft:NSLayoutConstraint!
    @IBOutlet weak var instructionTermLeft:NSLayoutConstraint!
    
    
    @IBOutlet weak var krView:UIView!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        scanRails.tintColor = UIColor.app
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scanViewController?.canScan = true
        self.showInstructionForMode()
        
        if DeveloperMode.isOn {
            instructionBrowserLeft.priority = UILayoutPriority(749)
            instructionTermLeft.priority = UILayoutPriority(751)
//            krView.isHidden = false

        } else {
            instructionBrowserLeft.priority = UILayoutPriority(751)
            instructionTermLeft.priority = UILayoutPriority(749)
//            krView.isHidden = true
        }
        
        self.view.layoutIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.denied
        {
            self.showSettings(with: "Camera Access", message: "Please enable camera access by tapping Settings. \(Properties.appName) needs the camera to scan your computer's QR code and pair. Pairing enables your computer to ask your phone for SSH logins.")
        }

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanner = segue.destination as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        }
        else if
                let pairingApproval = segue.destination as? PairApproveController,
                let pairing = sender as? Pairing
        {
            pairingApproval.pairing = pairing
            pairingApproval.scanController = scanViewController
            
            pairingApproval.didPairSuccessfully = {
                self.tabBarController?.selectedIndex = MainController.TabIndex.devices.index
            }
        }
        else if let pairingInvalid = segue.destination as? PairInvalidVersionController {
            pairingInvalid.scanController = scanViewController
        }
    }
    
    func showInstructionForMode() {

    }
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        // first try to see if it's a team QR code
        if case .some(let hasTeam) = try? IdentityManager.hasTeam(), !hasTeam,
            let adminQRPayload = try? AdminQRPayload(jsonString: data)
        {
            let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamMemberInPersonEmailController") as! TeamMemberInPersonEmailController
            controller.payload = adminQRPayload
            controller.didSkipScan = true
            
            dispatchMain { self.present(controller, animated: true, completion: nil) }
            
            return true
        }
        
        // next see if a totp code
        if let otpAuth = try? OTPAuth(urlString: data) {
            do {
                try OTPAuthManager.add(otpAuth: otpAuth)
                
                // move to the backup code controller
                let loading = LoadingController.present(from: self)
                loading?.showSuccess(hideAfter: 0.75) {
                    if let mainController = MainController.current {
                        if MainController.TabIndex.backupCodes.index < mainController.viewControllers?.count ?? 0,
                            let backupCodeController = mainController.viewControllers?[MainController.TabIndex.backupCodes.index] as? BackupCodesController
                        {
                            dispatchAfter(delay: 0.5) { dispatchMain { backupCodeController.showNewBackupCode() }}
                            
                        }
                        mainController.selectedIndex = MainController.TabIndex.backupCodes.index
                    }
                }
        
            } catch {
                showWarning(title: "Error", body: "Could not add backup code: \(error).")
                return false
            }
            
            return true
        }

        // otherwise must be a pairing
        guard let pairing = try? PairingQR(with: data).pairing else {
            dispatchMain { self.showInvalidPairingQR() }
            return false
        }
        
        guard pairing.version != nil else {
            dispatchMain { self.showInvalidWorkstationVersion() }
            return true
        }
        
        dispatchMain { self.showPairing(pairing: pairing) }

        return true
    }
    
    func showInvalidWorkstationVersion() {
        self.scanViewController?.canScan = false
        self.performSegue(withIdentifier: "showInvalidPairing", sender: nil)
    }
    
    func showInvalidPairingQR() {
        let invalidQRAlert = UIAlertController(title: "Invalid Code", message: "The QR you scanned is invalid. Tap Help for instructions on pairing \(Properties.appName) with your computer.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        invalidQRAlert.addAction(UIAlertAction(title: "Help", style: UIAlertActionStyle.default, handler: { (_) in
            dispatchMain { self.tabBarController?.performSegue(withIdentifier: "showInstall", sender: nil) }
        }))
        
        invalidQRAlert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (_) in
            self.scanViewController?.canScan = true
        }))

        
        self.present(invalidQRAlert, animated: true, completion: nil)
    }
    
    func showPairing(pairing: Pairing) {
        self.scanViewController?.canScan = false
        self.performSegue(withIdentifier: "showPairingApproval", sender: pairing)
    }
    
  
}


class PairInvalidVersionController:UIViewController {

    @IBOutlet weak var blurView:UIView!
    
    @IBOutlet weak var popupView:UIView!
    @IBOutlet weak var deviceLabel:UILabel!
    @IBOutlet weak var messageLabel:UILabel!
    
    @IBOutlet weak var upgradeLabel:UILabel!

    var scanController:KRScanController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowOffset = CGSize(width: 0, height: 0)
        popupView.layer.shadowOpacity = 0.2
        popupView.layer.shadowRadius = 3
        popupView.layer.masksToBounds = false

        upgradeLabel.text = UpgradeMethod.current
    }
    
    @IBAction func dismissTapped() {
        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()

        self.dismiss(animated: true, completion: {
            self.scanController?.canScan = true
        })

    }
}





