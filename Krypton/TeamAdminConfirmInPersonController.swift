//
//  TeamConfirmInPersonController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamConfirmInPersonController:KRBaseController {
    
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var createButton:UIButton!
    @IBOutlet weak var createView:UIView!
        
    var payload:NewMemberQRPayload!
    var identity:TeamIdentity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()
        
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        createButton.layer.shadowOpacity = 0.175
        createButton.layer.shadowRadius = 3
        createButton.layer.masksToBounds = false
        
        createView.layer.shadowColor = UIColor.black.cgColor
        createView.layer.shadowOffset = CGSize(width: 0, height: 0)
        createView.layer.shadowOpacity = 0.175
        createView.layer.shadowRadius = 3
        createView.layer.masksToBounds = false
        
        emailLabel.text = payload.email
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    @IBAction func createTeam() {
        self.run(syncOperation: {
            let invitation = SigChain.DirectInvitation(publicKey: self.payload.publicKey, email: self.payload.email)
            let (service, _) = try TeamService.shared().appendToMainChainSync(for: .directInvite(invitation))
            try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
        }, title: "Add \(self.payload.email)", onSuccess: {
            dispatchMain {
                self.performSegue(withIdentifier: "dismissToTeamsHome", sender: nil)
            }
        })

    }
    
}
