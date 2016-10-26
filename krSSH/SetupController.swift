//
//  SetupController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
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
        
        showSkip()
        
        keyIcon.FAIcon = FAType.FAKey
        
        do {
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.wireFormat()
            let fp = pk.fingerprint().hexPretty
            
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
        } else {
            email = UIDevice.current.name
        }
        
        do {
            try KeyManager.sharedInstance().setMe(email: email)
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
