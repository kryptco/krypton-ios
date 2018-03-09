//
//  TeamsMarketingController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/24/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamsMarketingController:KRBaseController {
    
    @IBOutlet weak var joinButton:UIButton!
    @IBOutlet weak var getStartedButton:UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for button in [getStartedButton!] {
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 0)
            button.layer.shadowOpacity = 0.175
            button.layer.shadowRadius = 3
            button.layer.masksToBounds = false
        }
    
    }
    
    @IBAction func createTeam() {
        
    }
    
    @IBAction func joinTeam() {
        let controller = Resources.Storyboard.TeamInvitations.instantiateViewController(withIdentifier: "TeamMemberInPersonScanController") as! TeamMemberInPersonScanController
        self.present(controller, animated: true, completion: nil)

    }

}


