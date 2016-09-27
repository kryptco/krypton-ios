//
//  SetupController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class SetupController: UIViewController, UITextFieldDelegate {

    @IBOutlet var keyIcon:UILabel!
    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet weak var identiconView:UIImageView!
    @IBOutlet weak var nameTextfield: UITextField!
    @IBOutlet weak var doneButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()
        
        doneButton.isEnabled = false
        
        keyIcon.FAIcon = FAType.FAKey
        identiconView.setBorder(color: UIColor.white, cornerRadius: 40.0, borderWidth: 0.0)

        do {
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.wireFormat()
            let fp = try pk.fingerprint().hexPretty
            
            keyLabel.text = fp.substring(to: fp.index(fp.startIndex, offsetBy: 32))
            identiconView.image = IGSimpleIdenticon.from(pk.toBase64(), size: CGSize(width: 100, height: 100))
            
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


    @IBAction func unwindToSetup(segue: UIStoryboardSegue) {
    }
    
    @IBAction func next() {
        nameTextfield.resignFirstResponder()
        
        do {
            try KeyManager.sharedInstance().setMe(email: nameTextfield.text ?? "unknown")
        } catch (let e) {
            log("Error saving email for keypair: \(e)", LogType.error)
            showWarning(title: "Error Saving", body: "Try again!")
            return
        }
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        doneButton.isEnabled = txtAfterUpdate.isEmpty == false
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    


}
