//
//  TeamCustomDomainInviteController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/15/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamCustomDomainInviteController:KRBaseController, UITextFieldDelegate {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var createButton:UIButton!
    @IBOutlet weak var createView:UIView!
    
    var name:String?
    
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
        
        nameTextField.isEnabled = true
        nameTextField.text = self.name
        
        setCreate(valid: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    func setCreate(valid:Bool) {
        
        if valid {
            self.createButton.alpha = 1
            self.createButton.isEnabled = true
        } else {
            self.createButton.alpha = 0.5
            self.createButton.isEnabled = false
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        setCreate(valid: !txtAfterUpdate.isEmpty && "a@\(txtAfterUpdate)".isValidEmail)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func createCustomDomainLink() {
        guard let domain = nameTextField.text else {
            return
        }
        
        var inviteLink:String?

        self.run(syncOperation: {
            let (service, response) = try TeamService.shared().appendToMainChainSync(for: .indirectInvite(.domain(domain)))
            inviteLink = response.data?.inviteLink
            try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
        }, title: "Create Team Invite Link", onSuccess: {
            if  let identity = (try? IdentityManager.getTeamIdentity()) as? TeamIdentity,
                let name = (try? identity.dataManager.withTransaction { try $0.fetchTeam().name }),
                let link = inviteLink
            {
                let text = Properties.invitationText(for: name)
                dispatchMain { self.presentShareActivity(link: link, text: text) }
            } else {
                self.showWarning(title: "Error", body: "Could not load invitation")
            }
        })
    

    }
    
    func presentShareActivity(link:String, text:String) {
        var items:[Any] = []
        items.append(text)
        
        if let urlItem = URL(string: link) {
            items.append(urlItem)
        }
        
        let share = UIActivityViewController(activityItems: items,
                                             applicationActivities: nil)
        
        
        share.completionWithItemsHandler = { (_, _, _, _) in
            self.dismiss(animated: true, completion: nil)
        }
        
        self.present(share, animated: true, completion: nil)
    }
    
    
}

