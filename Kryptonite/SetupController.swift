//
//  SetupController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit

class SetupController: UIViewController, UITextFieldDelegate {

    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet weak var nameTextfield: UITextField!
    @IBOutlet weak var doneButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        Onboarding.isActive = true
        
        do {
            let km = try KeyManager.sharedInstance()
            let pk = try km.keyPair.publicKey.wireFormat()
            let fp = pk.fingerprint().hexPretty
            
            if let email = try? IdentityManager.getMe() {
                nameTextfield.text = email
                showNext()
            } else {
                showSkip()
            }
            
            keyLabel.text = String(fp.prefix(32))
            
        } catch (let e) {
            self.showWarning(title: "Crypto Error", body: "\(e)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        dispatchAfter(delay: 1.0) { 
            self.nameTextfield.becomeFirstResponder()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func showSkip() {
        doneButton.setTitle("SKIP", for: UIControlState.normal)
        doneButton.setTitleColor(UIColor.lightGray, for: UIControlState.normal)
    }
    
    func showNext() {
        doneButton.setTitle("NEXT", for: UIControlState.normal)
        doneButton.setTitleColor(UIColor.app, for: UIControlState.normal)
    }

    @IBAction func unwindToSetup(segue: UIStoryboardSegue) {
    }
    
    @IBAction func next() {
        nameTextfield.resignFirstResponder()
        
        var email:String
        if let emailText = nameTextfield.text, !emailText.characters.isEmpty {
            email = emailText
            Analytics.postEvent(category: "email", action: "typed")
        } else {
            email = UIDevice.current.name
            Analytics.postEvent(category: "email", action: "skipped")
        }
        
        IdentityManager.setMe(email: email)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        if txtAfterUpdate.isEmpty {
            showSkip()
        } else {
            showNext()
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let firstPair = segue.destination as? FirstPairController {
            firstPair.firstTime = true
        }
    }
}
