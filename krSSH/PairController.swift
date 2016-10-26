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

        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == AVAuthorizationStatus.denied
        {
            self.showSettings(with: "Camera Access", message: "Please enable camera access by tapping Settings. We need the camera to scan your computer's QR code to pair with it. Pairing enables your computer to ask your phone for SSH logins.")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanner = segue.destination as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        } else if
                let pairingApproval = segue.destination as? PairApproveController,
                let pairing = sender as? Pairing
        {
            pairingApproval.pairing = pairing
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
            dispatchMain { self.showPairing(pairing: pairing) }
            return true
        }
        
        return false
    }
    
    func showPairing(pairing: Pairing) {
        self.scanViewController?.canScan = false
        self.performSegue(withIdentifier: "showPairingApproval", sender: pairing)
    }
    
  
}






