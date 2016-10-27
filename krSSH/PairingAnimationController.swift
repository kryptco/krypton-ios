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
    
    @IBOutlet weak var dots:UILabel!
    @IBOutlet weak var sessionLabel:UILabel!

    var session:Session?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        dots.pulse(scale: 1.25, duration: 1.0)
        
        guard let session = session else {
            self.showWarning(title: "Error Pairing", body: "Could not pair with machine. Try again.", then: { 
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        sessionLabel.text = "Pairing with \(session.pairing.displayName.uppercased())"

        let startTime = Date()
        
        Silo.shared.listen(to: session) { (success, error) in
            guard success && error == nil else {
                Silo.shared.remove(session: session)

                self.showWarning(title: "Error Pairing", body: "Could not pair with machine. Please try again.", then: {
                    self.dismiss(animated: true, completion: nil)
                })
                return
            }
            
            Analytics.postEvent(category: "first pairing", action: "success")

            SessionManager.shared.add(session: session)
            Silo.shared.add(session: session)
            Silo.shared.startPolling(session: session)
            
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
