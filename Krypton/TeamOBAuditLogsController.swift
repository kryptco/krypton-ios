//
//  TeamOBAuditLogsController.swift
//  Krypton
//
//  Created by Alex Grinman on 12/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
class TeamsOnboardingAuditLogsController:KRBaseController {
    
    @IBOutlet weak var enableSwitch: UISwitch!
    @IBOutlet weak var enableLabel: UILabel!
    
    @IBOutlet weak var contentView:UIView!
    @IBOutlet weak var nextButton:UIButton!
    
    var settings:CreateFromAppSettings!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()
        
        for v in [contentView, nextButton] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
        
        enableSwitch.isOn = true
        valueChanged()
    }
    
    
    @IBAction func valueChanged() {
        enableLabel.text = enableSwitch.isOn ? "enabled" : "disabled"
        settings.auditLoggingEnabled = enableSwitch.isOn
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let next = segue.destination as? TeamsOnboardingAutoApproveController {
            next.settings = self.settings
        }
    }
}
