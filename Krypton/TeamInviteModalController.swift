//
//  TeamInviteModalController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/16/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

protocol TeamInviteModalDelegate {
    func selected(option: TeamInviteModalOption)
}

enum TeamInviteModalOption {
    case teamDomainLink
    case individualsLink
    case inPerson
    case other
}

class TeamInviteModalController:KRBaseController {
    
    var delegate:TeamInviteModalDelegate?
    var domain:String?
    
    @IBOutlet weak var domainDetaiLabel:UILabel!
    
    func domainOnlyText(domain:String?) -> String {
        if let domain = domain {
            return "Anyone with a @\(domain) email address"
        }
        
        return "Anyone with a specific email domain chosen by you"
    }
    
    @IBOutlet weak var bottomConstraint:NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        domainDetaiLabel.text = domainOnlyText(domain: domain)
        
        bottomConstraint.constant = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.25, animations: {
            
            self.bottomConstraint.constant = 0
            self.view.layoutIfNeeded()
            
        }, completion: nil)
    }
    
    @IBAction func gestureDismiss() {
        UIView.animate(withDuration: 0.5, animations: {
            
            self.bottomConstraint.constant = -2000
            self.view.layoutIfNeeded()
            
        }, completion: { _ in
            self.dismiss(animated: true, completion: nil)
        })

    }

    @IBAction func teamLink() {
        self.dismiss(animated: true) {
            self.delegate?.selected(option: .teamDomainLink)
        }
    }
    
    @IBAction func individualsLink() {
        self.dismiss(animated: true) {
            self.delegate?.selected(option: .individualsLink)
        }
    }
    
    @IBAction func inPerson() {
        self.dismiss(animated: true) {
            self.delegate?.selected(option: .inPerson)
        }
    }
    
    @IBAction func other() {
        self.dismiss(animated: true) {
            self.delegate?.selected(option: .other)
        }
    }
}
