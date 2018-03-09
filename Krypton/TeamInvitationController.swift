//
//  TeamInvitationController.swift
//  Krypton
//
//  Created by Alex Grinman on 7/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamInvitationController:UIViewController, UITextFieldDelegate {
    
    var joinType:TeamJoinType!
    var teamIdentity:TeamIdentity?
    var teamName:String?

    @IBOutlet weak var teamNameLabel:UILabel!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var joinButton:UIButton!

    @IBOutlet weak var emailView:UIView!

    @IBOutlet weak var stepLabel:UILabel!

    @IBOutlet weak var emailSubtitleLabel:UILabel!

    @IBOutlet weak var emailLine:UIView!

    @IBOutlet weak var emailVerificationSentLabel:UILabel!
    @IBOutlet weak var emailVerifyResendButton:UIButton!
    @IBOutlet weak var changeEmailButton:UIButton!

    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!
    
    
    @IBOutlet weak var domainLabel:UILabel!


    var linkListener:LinkListener?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        joinButton.layer.shadowColor = UIColor.black.cgColor
        joinButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        joinButton.layer.shadowOpacity = 0.175
        joinButton.layer.shadowRadius = 3
        joinButton.layer.masksToBounds = false
        
        emailView.layer.shadowColor = UIColor.black.cgColor
        emailView.layer.shadowOffset = CGSize(width: 0, height: 0)
        emailView.layer.shadowOpacity = 0.175
        emailView.layer.shadowRadius = 3
        emailView.layer.masksToBounds = false
        
        if let teamIdentity = self.teamIdentity, teamIdentity.email.isValidEmail {
            emailTextfield.text = teamIdentity.email
        } else if let email = try? IdentityManager.getMe(), email.isValidEmail {
            emailTextfield.text = email
        } else {
            emailTextfield.becomeFirstResponder()
        }
        
        emailTextfield.isEnabled = true
        teamNameLabel.text = teamName
        
        // hide email verification
        showDefaultElements()
        
        if  case .indirectInvite(let indirect) = joinType!,
            case .domain(let domain) = indirect.restriction
        {
            emailTextfield.placeholder = "alice"
            self.domainLabel.text = "@\(domain)"
            
            if let email = emailTextfield.text {
                emailTextfield.text = email.components(separatedBy: "@").first
            }
        } else {
            self.domainLabel.text = ""
        }

        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        linkListener = LinkListener(self.onListen)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }
    
    
    func setJoin(valid:Bool) {
        
        if valid {
            self.joinButton.alpha = 1
            self.joinButton.isEnabled = true
        } else {
            self.joinButton.alpha = 0.5
            self.joinButton.isEnabled = false
        }
    }
    
    
    @IBAction func joinTapped() {
        
        guard var email = emailTextfield.text
        else {
            self.showWarning(title: "Error", body: "Invalid email address. Please enter a valid team email", then: {
                self.dismiss(animated: true, completion: nil)
            })
            return
        }
        
        // ensure email is one valid if an email invite
        if  case .indirectInvite(let indirect) = joinType!,
            case .emails(let emails) = indirect.restriction,
            emails.contains(email) == false
        {
            self.showWarning(title: "Email invalid",
                             body: "This invitation is only valid for:\n\(emails.joined(separator: "\n")).")
            {
                self.dismiss(animated: true, completion: nil)
            }
            return
        }

        // format the email correctly for a domain invite
        if  case .indirectInvite(let indirect) = joinType!,
            case .domain(let domain) = indirect.restriction
        {
            email = "\(email)@\(domain)"
        }

        
        // set the team identity's email
        switch joinType! {
        case .indirectInvite, .directInvite:
            guard var teamIdentity = self.teamIdentity else {
                self.showWarning(title: "Error", body: "Fatal error missing team identity information.") {
                    self.dismiss(animated: true, completion: nil)
                }
                return
            }
            teamIdentity.email = email
            
            self.doVerifyEmail(for: email, using: teamIdentity, onError: { (error) in
                self.showWarning(title: "Error Verifying Email", body: "\(error)")
            }, onSuccess: {
                dispatchMain {
                    self.performSegue(withIdentifier: "showTeamsComplete", sender: teamIdentity)
                }
            })
        
        case .createFromApp(let settings):
            createTeam(with: email, name: settings.name)
        }
        
    }
    
    @IBAction func unwindToTeamInvitation(segue: UIStoryboardSegue) {
        showDefaultElements()
    }
    
    
    @IBAction func cancelTapped() {
        self.dontJoinTapped()
    }

    @IBAction func dontJoinTapped() {
        switch joinType! {
        case .directInvite, .indirectInvite:
            self.dismiss(animated: true, completion: nil)
            
        case .createFromApp:
            self.navigationController?.popToRootViewController(animated: true)

        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let text = textField.text ?? ""
        var txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        if  case .indirectInvite(let indirect) = joinType!,
            case .domain(let domain) = indirect.restriction
        {
            txtAfterUpdate = "\(txtAfterUpdate)@\(domain)"
        }

        let valid = txtAfterUpdate.isValidEmail
        
        setJoin(valid: valid)
        
        if !valid, !txtAfterUpdate.isEmpty {
            emailLine.backgroundColor = UIColor.reject
        } else {
            emailLine.backgroundColor = UIColor.app
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField.text?.isValidEmail == true {
            self.joinTapped()
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let completeController = segue.destination as? TeamJoinCompleteController {
            completeController.joinType = joinType
            completeController.teamName = teamName
            
            if let identity = sender as? TeamIdentity {
                completeController.teamIdentity = identity
            } else if let (identity, createBlock) = sender as? (TeamIdentity, SigChain.SignedMessage) {
                completeController.teamIdentity = identity
                completeController.createBlock = createBlock
            }
        }
    }
    
    // MARK: Email verification UI
    func hideSpinner() {
        self.checkBox.setCheckState(M13Checkbox.CheckState.unchecked, animated: false)
        checkBox.alpha = 0
        arcView.alpha = 0
    }
    
    func showSpinner() {
        checkBox.alpha = 1
        arcView.alpha = 1
    }
    
    func showSpinnerSuccess() {
        self.checkBox.secondaryCheckmarkTintColor = UIColor.app
        self.checkBox.tintColor = UIColor.app

        dispatchMain {
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
            }) { (_) in
                self.checkBox.toggleCheckState(true)
            }
        }
    }
    
    func showDefaultElements() {
        hideSpinner()
        setJoin(valid: (emailTextfield.text ?? "").isValidEmail)
        emailSubtitleLabel.alpha = 1
        emailTextfield.isEnabled = true

        switch joinType! {
        case .directInvite, .indirectInvite:
            stepLabel.text = ""
            joinButton.setTitle("JOIN", for: UIControlState.normal)
            
        case .createFromApp:
            stepLabel.text = "Last step"
            joinButton.setTitle("CREATE", for: UIControlState.normal)
        }
        
        [self.emailVerificationSentLabel, self.emailVerifyResendButton, self.changeEmailButton].forEach {
            $0.alpha = 0.0
        }
        

    }

    func showEmailVerificationSent() {
        self.joinButton.isEnabled = false
        showSpinnerSuccess()
        emailSubtitleLabel.alpha = 0
        emailTextfield.isEnabled = false
        
        dispatchAfter(delay: 0.5) {
            UIView.animate(withDuration: 0.5, animations: {
                self.hideSpinner()

            }, completion: { (_) in
                UIView.animate(withDuration: 1.5, animations: {
                    self.joinButton.alpha = 0.5
                    
                    [self.emailVerificationSentLabel, self.emailVerifyResendButton, self.changeEmailButton].forEach {
                        $0.alpha = 1.0
                    }
                }) { (_) in
                    self.checkBox.toggleCheckState(false)
                }

            })
            
        }
        
    }
    @IBAction func changeEmailTapped() {
        self.onReceiveChallenge = nil
        self.showDefaultElements()
        self.emailTextfield.becomeFirstResponder()
    }

    @IBAction func resendTapped() {
        dispatchMain {
            self.showDefaultElements()
            self.showSpinner()
        }

        self.resendHandler?()
    }
        
    func onVerifyEmailError(error:Error) {
        dispatchMain {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
                self.showWarning(title: "Error Verifying Email", body: "\(error)") {
                    self.showDefaultElements()
                }
            }

        }
    }
    
    // MARK: Create Team
    
    func createTeam(with email:String, name:String) {
        do {
            let (identity, createBlock) = try TeamIdentity.newAdmin(email: email, teamName: name)
            
            self.doVerifyEmail(for: email, using: identity, onError: onVerifyEmailError, onSuccess:
            {
                dispatchMain {
                    self.performSegue(withIdentifier: "showTeamsComplete", sender: (identity, createBlock))
                }
            })
            
        } catch {
            self.showWarning(title: "Error", body: "Could not create team identity. \(error). Please try again.")
            return
        }
    }
    
    
    //MARK: Email verification (send + create)
    var onReceiveChallenge:((SigChain.EmailChallenge)->())? = nil
    var resendHandler:(()->())? = nil

    func doVerifyEmail(for email:String, using teamIdentity:TeamIdentity, onError:@escaping (Error)->(), onSuccess: @escaping ()->()) {
        let temporaryService = TeamService.temporary(for: teamIdentity)

        self.onReceiveChallenge = { challenge in
            dispatchMain {
                self.showDefaultElements()
                self.setJoin(valid: false)
                self.showSpinner()
            }

            do {
                try temporaryService.verifyEmail(with: challenge, { (result) in
                    switch result {
                    case .error(let e):
                        onError(e)
                    case .result:
                        onSuccess()
                    }
                })
            } catch {
                onError(error)
            }
        }
        
        dispatchMain {
            self.setJoin(valid: false)
            self.showSpinner()
        }
        
        let resendHandler = {
            temporaryService.sendEmailChallenge(for: email) { (result) in
                switch result {
                case .error(let e):
                    onError(e)
                case .result:
                    dispatchMain {
                        self.showEmailVerificationSent()
                    }
                }
            }
        }
        
        self.resendHandler = resendHandler
        resendHandler()
    }
    
    func onListen(link:Link) {
        
        var nonce:String
        
        switch link.type {
        case .app:
            guard case .emailChallenge = link.command.host else {
                log("invalid link command presented: \(link.type)", .error)
                return
            }
            
            guard let theNonce = link.path.first
            else {
                log("invalid url path: \(link.path)", .error)
                return
            }
            
            nonce = theNonce
            
        case .site:
            guard case .emailChallengeRemote = link.command.host else {
                log("invalid link command presented: \(link.type)", .error)
                return
            }

            guard let theNonce = link.properties["nonce"]
            else {
                log("invalid url query parameters: \(link.properties)", .error)
                return
            }
            
            nonce = theNonce
        }
        
        
        do {
            let emailChallenge = try SigChain.EmailChallenge(nonce: nonce.fromBase64())
            self.onReceiveChallenge?(emailChallenge)
        } catch {
            self.onVerifyEmailError(error: error)
        }
    }
}





