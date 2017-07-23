//
//  TeamGenerateController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamGenerateController:KRBaseController {
    @IBOutlet weak var animationView:UIView!
    @IBOutlet weak var teamNameLabel:UILabel!

    var keyType:KeyType!
    var identity:Identity!
    var invite:TeamInvite!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        teamNameLabel.text = invite.team.name
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let teamsCompleteController = segue.destination as? TeamJoinCompleteController {
            teamsCompleteController.invite = invite
            teamsCompleteController.identity = identity
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        SwiftSpinner.useContainerView(animationView)
        SwiftSpinner.show("", animated: true)
        
        let startTime = Date()
        
        dispatchAsync {
            do {
                
                //TODO: remove double check that it's not default key
                if self.identity.usesDefaultKey == false {
                    try KeyManager.generateKeyPair(type: self.keyType, for: self.identity)
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                
                let kp = try KeyManager.sharedInstance(for: self.identity).keyPair
                let pk = try kp.publicKey.export().toBase64()
                
                log("Generated public key: \(pk)")
                
                if elapsed >= 3.0 {
                    dispatchMain {
                        SwiftSpinner.hide()
                        self.performSegue(withIdentifier: "showTeamsComplete", sender: nil)
                    }
                    return
                }
                
                dispatchAfter(delay: 3.0 - elapsed, task: {
                    dispatchMain {
                        SwiftSpinner.hide()
                        self.performSegue(withIdentifier: "showTeamsComplete", sender: nil)
                    }
                })
                
            } catch (let e) {
                self.showWarning(title: "Error", body: "Cryptography: error generating key pair. \(e)", then: {
                    dispatchMain {
                        SwiftSpinner.hide()
                        self.dismiss(animated: true, completion: nil)
                    }
                })
            }
        }
    }
    
}
