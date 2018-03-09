//
//  TeamMemberInPersonScanController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class TeamMemberInPersonScanController: KRBaseController, KRScanDelegate {
    
    var scanViewController:KRScanController?
    @IBOutlet weak var createView:UIView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createView.layer.shadowColor = UIColor.black.cgColor
        createView.layer.shadowOffset = CGSize(width: 0, height: 0)
        createView.layer.shadowOpacity = 0.175
        createView.layer.shadowRadius = 3
        createView.layer.masksToBounds = false
        
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
            self.showSettings(with: "Camera Access",
                              message: "Please enable camera access by tapping Settings. \(Properties.appName) needs the camera to scan the QR code on your new team member's device to add them to the team.")
        }
    }
    
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func backToDisplayScanner(segue: UIStoryboardSegue) {
    }
    
    @IBAction func unwindAndDismiss(segue: UIStoryboardSegue) {
        self.dismiss(animated: true, completion: nil)
    }

    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanner = segue.destination as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        } else  if let emailController = segue.destination as? TeamMemberInPersonEmailController,
            let payload = sender as? AdminQRPayload
        {
            emailController.payload = payload
        }
    }
    
    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        guard let payload = try? AdminQRPayload(jsonString: data) else {
            dispatchMain { self.showInvalidQR() }
            return true
        }
        
        dispatchMain {
            self.performSegue(withIdentifier: "showEmailInput", sender: payload)
        }
        return true
    }
    
    func showInvalidQR() {
        let invalidQRAlert = UIAlertController(title: "Invalid Code", message: "The QR you scanned is invalid.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        invalidQRAlert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (_) in
            self.scanViewController?.canScan = true
        }))
        
        self.present(invalidQRAlert, animated: true, completion: nil)
    }
    
    
}
