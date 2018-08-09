//
//  MeController.swift
//  Krypton
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class MeController:KRBaseController, UITextFieldDelegate {
    
    @IBOutlet weak var brewButton:UIButton!
    @IBOutlet weak var curlButton:UIButton!
    @IBOutlet weak var npmButton:UIButton!
    @IBOutlet weak var moreButton:UIButton!
    @IBOutlet weak var installCard:UIView!
    @IBOutlet weak var installLabel:UILabel!

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
        
        for v in [installCard, meCommandWindow, otherCommandWindow, codeSigningWindow] {
            v?.setBoxShadow()
        }
        setCurlState()
        setGitHubState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //shareButton.setBorder(color: UIColor.clear, cornerRadius: 20, borderWidth: 0.0)

        Current.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func brewTapped() {
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.brew.command
        
        Analytics.postEvent(category: "onboard_install", action: "brew")
    }
    
    @IBAction func npmTapped() {
        disableAllInstallButtons()
        
        npmButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.npm.command
        
        Analytics.postEvent(category: "onboard_install", action: "npm")
    }
    
    func setCurlState() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.curl.command
    }
    
    @IBAction func curlTapped() {
        setCurlState()
        
        Analytics.postEvent(category: "onboard_install", action: "curl")
    }
    
    @IBAction func moreTapped() {
        disableAllInstallButtons()
        
        moreButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        installLabel.text = InstallMethod.more.command
        
        Analytics.postEvent(category: "onboard_install", action: "more")
    }
    
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        npmButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        moreButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
    }
    

   
    //MARK: Add Public Key Helper
    
    enum UploadMethod:String {
        case github = "kr github"
        case digitalOcean = "kr digitalocean"
        case aws = "kr aws"
    }
    
    
    
    func setGitHubState() {
        disableAllUploadMethods()
        
        githubButton.setTitleColor(UIColor.appBlueGray, for: UIControlState.normal)
        githubLine.backgroundColor = UIColor.appBlueGray
        addCommandLabel.text = UploadMethod.github.rawValue
    }
    
    @IBAction func githubTapped() {
        setGitHubState()
        Analytics.postEvent(category: "add key", action: "GitHub")
    }
    
    
    @IBAction func doTapped() {
        disableAllUploadMethods()
        
        doButton.setTitleColor(UIColor.appBlueGray, for: UIControlState.normal)
        doLine.backgroundColor = UIColor.appBlueGray
        addCommandLabel.text = UploadMethod.digitalOcean.rawValue
     
        Analytics.postEvent(category: "add key", action: "DigitalOcean")
    }

    @IBAction func awsTapped() {
        disableAllUploadMethods()
        
        awsButton.setTitleColor(UIColor.appBlueGray, for: UIControlState.normal)
        awsLine.backgroundColor = UIColor.appBlueGray
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
    
    @IBAction func editKnownHostsTapped() {
        let knownHostsController = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "KnownHostsEditController") as! KnownHostsEditController
        self.navigationController?.pushViewController(knownHostsController, animated: true)
        
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
        return true
    }
    
    //MARK: Segue
    @IBAction func dismissQR(segue: UIStoryboardSegue) {
    }
    
}
