//
//  TeamsOBApprovalIntervalController.swift
//  Krypton
//
//  Created by Alex Grinman on 12/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TeamsOnboardingAutoApproveController:KRBaseController {
    
    @IBOutlet weak var approvalSlider: UISlider!
    @IBOutlet weak var alwaysAsk: UILabel!
    @IBOutlet weak var oneHour: UILabel!
    @IBOutlet weak var threeHours: UILabel!
    
    @IBOutlet weak var alwaysAskButton: UIButton!
    @IBOutlet weak var oneHourButton: UIButton!
    @IBOutlet weak var threeHoursButton: UIButton!

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
        
        snapToThreeHours()
    }
    
    @IBAction func nextTapped() {
        
        // skip known hosts if we dont have any
        if let all = try? KnownHostManager.shared.fetchAll(), all.isEmpty {
            self.performSegue(withIdentifier: "showCreateTeamFromApp", sender: nil)
        } else {
            self.performSegue(withIdentifier: "showCreateOnboardingKnownHosts", sender: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let loadController = segue.destination as? TeamLoadController {
            loadController.joinType = .createFromApp(self.settings)
        } else if  let next = segue.destination as? TeamsOnboardingPinHostsController {
            next.settings = self.settings
        }
        
    }
    
    
    func highlight(label:UILabel) {
        [alwaysAsk, oneHour, threeHours].forEach {
            $0?.textColor = UIColor.gray
        }
        
    
        
        label.textColor = UIColor.app
    }
    
    func hide(button:UIButton) {
        [alwaysAskButton, oneHourButton, threeHoursButton].forEach {
            $0?.isHidden = false
        }
        
        
        
        button.isHidden = true
    }

    
    @IBAction func snapToAlwaysAsk() {
        approvalSlider.value = 0
        valueChanged()
    }
    
    @IBAction func snapToOneHour() {
        approvalSlider.value = 1
        valueChanged()
    }
    @IBAction func snapToThreeHours() {
        approvalSlider.value = 2
        valueChanged()
    }

    
    @IBAction func valueChanged() {
        let valueFixed = Int(approvalSlider.value + 0.5)
        approvalSlider.setValue(Float(valueFixed), animated: true)
        
        switch valueFixed {
        case 0:
            highlight(label: alwaysAsk)
            hide(button: alwaysAskButton)
            self.settings.autoApprovalInterval = 0
        case 1:
            highlight(label: oneHour)
            hide(button: oneHourButton)
            self.settings.autoApprovalInterval = TimeSeconds.hour.multiplied(by: 1)
        case 2:
            highlight(label: threeHours)
            hide(button: threeHoursButton)
            self.settings.autoApprovalInterval = TimeSeconds.hour.multiplied(by: 3)
            
        default:
            approvalSlider.value = 0
            valueChanged()
            return
        }
    }
}
