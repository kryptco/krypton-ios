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
    @IBOutlet var tagTextField:UITextField!
    
    @IBOutlet var meCommandWindow:UIView!
    @IBOutlet var otherCommandWindow:UIView!
    @IBOutlet var codeSigningWindow:UIView!

    @IBOutlet var addCommandLabel:UILabel!

    @IBOutlet var githubButton:UIButton!
    @IBOutlet var githubLine:UIView!

    @IBOutlet var doButton:UIButton!
    @IBOutlet var doLine:UIView!
    
    @IBOutlet var awsButton:UIButton!
    @IBOutlet var awsLine:UIView!

    var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for v in [meCommandWindow, otherCommandWindow, codeSigningWindow] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
        
        setGitHubState()

        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //shareButton.setBorder(color: UIColor.clear, cornerRadius: 20, borderWidth: 0.0)

        redrawMe()
        Current.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func redrawMe() {
        do {
            tagTextField.text = try IdentityManager.getMe()
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error", body: "Could not get user data. \(e)")
        }
    }
   
    //MARK: Add Public Key Helper
    
    enum UploadMethod:String {
        case github = "kr github"
        case digitalOcean = "kr digitalocean"
        case aws = "kr aws"
    }
    
    
    
    func setGitHubState() {
        disableAllUploadMethods()
        
        githubButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        githubLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.github.rawValue
    }
    
    @IBAction func githubTapped() {
        setGitHubState()
        Analytics.postEvent(category: "add key", action: "GitHub")
    }
    
    
    @IBAction func doTapped() {
        disableAllUploadMethods()
        
        doButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        doLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.digitalOcean.rawValue
     
        Analytics.postEvent(category: "add key", action: "DigitalOcean")
    }

    @IBAction func awsTapped() {
        disableAllUploadMethods()
        
        awsButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        awsLine.backgroundColor = UIColor.app
        addCommandLabel.text = UploadMethod.aws.rawValue
        
        Analytics.postEvent(category: "add key", action: "AWS")
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
        guard   let email = try? IdentityManager.getMe(),
                let publicKeyAuthorized = try? KeyManager.sharedInstance().keyPair.publicKey.authorizedFormat()
        else {
            return
        }

        Analytics.postEvent(category: "me share", action: "public key")

        dispatchMain {
            self.present(self.otherDialogue(for: email, authorizedKey: publicKeyAuthorized), animated: true, completion: nil)
        }
    }
    
    @IBAction func getMyTeamTapped() {
        Analytics.postEvent(category: "me share", action: "kryptonite with team")

        let textItem = "Team, please use Kryptonite to securely store your SSH private key on your phone. You no longer have to worry that your plain-text keys in the ~/.ssh/ directory are vulnerable. Kryptonite ensures the private key never leaves the device, and gives you ability to know everytime your key is used. Simply pair your phone with your computer once, and you're all set. "
        
        var items:[Any] = [textItem]

        if let linkItem = URL(string: Properties.appURL) {
            items.append(linkItem)
        }
        
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        self.present(activityController, animated: true, completion: nil)
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
            tagTextField.text = (try? IdentityManager.getMe()) ?? ""
        } else {
           IdentityManager.setMe(email: email)
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    //MARK: Segue
    @IBAction func dismissQR(segue: UIStoryboardSegue) {
    }
    
}
