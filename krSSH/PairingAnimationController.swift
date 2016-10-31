//
//  PairingAnimationController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class PairingAnimationController:UIViewController {
    
    @IBOutlet weak var sessionLabel:UILabel!

    @IBOutlet weak var dot1:UIView!
    @IBOutlet weak var dot2:UIView!
    @IBOutlet weak var dot3:UIView!

    var session:Session?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        var delay = 0.1
        for dot in [dot1,dot2,dot3] {
            dispatchAfter(delay: delay, task: { 
                dispatchMain { dot?.pulse(scale: 1.2, duration: 0.5) }
            })
            delay += 0.1
        }
        
        guard let session = session else {
            self.showWarning(title: "Error Pairing", body: "Could not pair with machine. Try again.", then: { 
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        sessionLabel.text = "Pairing with \(session.pairing.displayName.uppercased())"

        let startTime = Date()
        
        dispatchAsync {
            guard Silo.shared.waitForPairing(session: session) else {
                Silo.shared.remove(session: session)
                self.showWarning(title: "Error Pairing", body: "Timed out. Please make sure Bluetooth is on or you have an internet connection and try again.",
                then: {
                    (self.presentingViewController as? FirstPairController)?.scanController?.canScan = true
                    self.dismiss(animated: true, completion: nil)
                })
                
                Analytics.postEvent(category: "device", action: "pair", label: "failed")
                return
            }
            
            SessionManager.shared.add(session: session)
            
            let delay = abs(Date().timeIntervalSince(startTime))
            
            if delay >= 2.0 {
                dispatchMain {
                    self.performSegue(withIdentifier: "showDone", sender: nil)
                }
                return
            }
            
            dispatchAfter(delay: 2.0 - delay, task: {
                dispatchMain {
                    self.performSegue(withIdentifier: "showDone", sender: nil)
                }
            })

        }

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let doneController = segue.destination as? PairedUploadController {
            doneController.session = session
        }
    }
}
