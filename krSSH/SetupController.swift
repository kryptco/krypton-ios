//
//  SetupController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class SetupController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var keyIcon:UILabel!
    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet var identiconView:UIImageView!

    @IBOutlet weak var nameTextfield: UITextField!

    var doneButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setKrLogo()

        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(SetupController.done))
        doneButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = doneButton
        
        keyIcon.FAIcon = FAType.FAKey
        identiconView.setBorder(color: UIColor.white, cornerRadius: 50.0, borderWidth: 0.0)
        
        do {
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.exportSecp()
            
            if let fp = pk.secp256Fingerprint?.hexPretty {
                keyLabel.text = fp.substring(to: fp.index(fp.startIndex, offsetBy: 32))
            }
            identiconView.image = IGSimpleIdenticon.from(pk, size: CGSize(width: 100, height: 100))
            
        } catch (let e) {
            self.showWarning(title: "Crypto Error", body: "\(e)")
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nameTextfield.becomeFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    dynamic func done () {
        nameTextfield.resignFirstResponder()
        
        do {
            try KeyManager.sharedInstance().setMe(email: nameTextfield.text ?? "unknown")
        } catch (let e) {
            log("Error saving email for keypair: \(e)", LogType.error)
            showWarning(title: "Error Saving", body: "Try again!")
            return
        }
        
        self.navigationController?.dismiss(animated: true, completion: nil)
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
