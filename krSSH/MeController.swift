//
//  MeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class MeController:KRBaseController, UITextFieldDelegate {
    @IBOutlet var identiconButton:KRSimpleButton!
    @IBOutlet var tagTextField:UITextField!

    @IBOutlet var shareButton:UIButton!

    
    @IBOutlet var meCommandWindow:UIView!
    @IBOutlet var otherCommandWindow:UIView!

    @IBOutlet var addCommandLabel:UILabel!

    @IBOutlet var githubButton:UIButton!
    @IBOutlet var githubLine:UIView!

    @IBOutlet var doButton:UIButton!
    @IBOutlet var doLine:UIView!
    
    @IBOutlet var awsButton:UIButton!
    @IBOutlet var awsLine:UIView!

    @IBInspectable var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for v in [meCommandWindow, otherCommandWindow] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }

        githubTapped()

        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        shareButton.setBorder(color: UIColor.clear, cornerRadius: 20, borderWidth: 0.0)

        redrawMe()
        Policy.currentViewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
     func redrawMe() {
        
        do {
            
            let me = try KeyManager.sharedInstance().getMe()
            tagTextField.text = me.email
            
            identiconButton.setImage(IGSimpleIdenticon.from(me.publicKey.toBase64(), size: CGSize(width: 80, height: 80)), for: UIControlState.normal)
            
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error", body: "Email address not found.")
        }
    }
   
    //MARK: Add Public Key Helper
    
    enum UploadMethod:String {
        case github = "kr github"
        case digitalOcean = "kr digital-ocean"
        case aws = "kr aws"
    }
    
    @IBAction func githubTapped() {
        disableAllUploadMethods()
        
        githubButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        githubLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.github.rawValue
        
    }

    @IBAction func doTapped() {
        disableAllUploadMethods()
        
        doButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        doLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.digitalOcean.rawValue
        
    }

    @IBAction func awsTapped() {
        disableAllUploadMethods()
        
        awsButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        awsLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.aws.rawValue

    }
    
    func disableAllUploadMethods() {
        
        githubButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        doButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        awsButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)

        githubLine.backgroundColor = UIColor.clear
        doLine.backgroundColor = UIColor.clear
        awsLine.backgroundColor = UIColor.clear
    }

    
    //MARK: Sharing
    @IBAction func shareOtherTapped() {
        guard let me = try? KeyManager.sharedInstance().getMe()
        else {
            return
        }

        
        dispatchMain {
            self.present(self.otherDialogue(for: me, me: true), animated: true, completion: nil)
        }
    }
    
    
    //MARK: TextField Delegate -> Editing Email
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
//        let text = textField.text ?? ""
//        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let email = textField.text else {
            return false
        }
        
        if email.isEmpty {
            tagTextField.text = (try? KeyManager.sharedInstance().getMe().email) ?? ""
        } else {
           try? KeyManager.sharedInstance().setMe(email: email)
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    //MARK: Segue
    @IBAction func dismissQR(segue: UIStoryboardSegue) {
    }
    
    //MARK: Identicon
    @IBAction func identiconTapped() {
        let alert = UIAlertController(title: "Public Key Identicon", message: "This is your public key identicon. It is a visual representation of the hash of your SSH public key.", preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    
}
