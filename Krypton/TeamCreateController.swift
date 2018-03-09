//
//  TeamCreateController.swift
//  Krypton
//
//  Created by Alex Grinman on 12/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamsCreateController:KRBaseController, UITextFieldDelegate {
    
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
        
        setCreate(valid: !txtAfterUpdate.isEmpty)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func createTeam() {
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let next = segue.destination as? TeamsOnboardingAuditLogsController, let name = self.nameTextField.text
        {
            next.settings = CreateFromAppSettings(name: name)
        }
    }
    
}
