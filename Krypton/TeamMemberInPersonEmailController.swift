//
//  TeamMemberInPersonEmailController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamMemberInPersonEmailController:KRBaseController, UITextFieldDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var createButton:UIButton!
    @IBOutlet weak var createView:UIView!
    @IBOutlet weak var teamLabel:UILabel!
    @IBOutlet weak var backButton:UIButton!

    var didSkipScan = false

    // indicates create team originated from a request
    var payload:AdminQRPayload!
    
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
        
        emailTextField.isEnabled = true
        teamLabel.text = payload.teamName
        
        if didSkipScan {
            self.backButton.addTarget(self, action: #selector(TeamMemberInPersonEmailController.dismissFlow), for: .touchUpInside)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let email = try? IdentityManager.getMe(), email.isValidEmail {
            emailTextField.text = email
            setCreate(valid: email.isValidEmail)

        } else {
            emailTextField.becomeFirstResponder()
            setCreate(valid: false)
        }
        

    }
    
    @objc func dismissFlow() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func backToEmailInput(segue: UIStoryboardSegue) {
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
        
        setCreate(valid: !txtAfterUpdate.isEmpty)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func nextTapped() {
        guard let email = emailTextField.text, email.isValidEmail else {
            self.showWarning(title: "Error", body: "Not valid email.")
            return
        }
        
        self.performSegue(withIdentifier: "showQR", sender: email)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let next = segue.destination as? TeamMemberInPersonQRController,
            let email = self.emailTextField.text
        {
            next.email = email
            next.payload = payload
        }
    }
    
}
