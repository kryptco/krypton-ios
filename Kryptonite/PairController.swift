//
//  ExchangeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class PairController: KRBaseController, KRScanDelegate {
    
    var scanViewController:KRScanController?
    @IBOutlet weak var scanRails:UIImageView!

    

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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.denied
        {
            self.showSettings(with: "Camera Access", message: "Please enable camera access by tapping Settings. Kryptonite needs the camera to scan your computer's QR code and pair. Pairing enables your computer to ask your phone for SSH logins.")
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
            pairingApproval.tabController = tabBarController
        }
        else if let pairingInvalid = segue.destination as? PairInvalidVersionController {
            pairingInvalid.scanController = scanViewController
        }
    }
    
    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard let pairing = try? Pairing(jsonString: data) else {
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
        let invalidQRAlert = UIAlertController(title: "Invalid Code", message: "The QR you scanned is invalid. Please tap help for assistance installing and using the kr command line utility to pair with Kryptonite.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
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
        
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        self.dismiss(animated: true, completion: {
            self.scanController?.canScan = true
        })

    }
}





