//
//  TeamJoinCompleteController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/21/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class TeamJoinCompleteController:KRBaseController {
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var joiningLabel:UILabel!
    @IBOutlet weak var teamNameLabel:UILabel!
    @IBOutlet weak var welcomeLabel:UILabel!

    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewUp:NSLayoutConstraint!
    @IBOutlet weak var resultViewDown:NSLayoutConstraint!


    var joinType:TeamJoinType!
    var teamIdentity:TeamIdentity!
    
    struct JoinWorkflowError:Error, CustomDebugStringConvertible  {
        let error:Error
        let action:String
        
        init(_ error:Error, action:String) {
            self.error = error
            self.action = action
        }
        var debugDescription: String {
            return "\(action). Internal message: \(error)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        teamNameLabel.text = teamIdentity.team.name
        
        resultViewUp.priority = 750
        resultViewDown.priority = 999
        self.view.layoutIfNeeded()
        
        switch joinType! {
        case .invite:
            joiningLabel.text = "JOINING"
            welcomeLabel.text = "Welcome to the team!"
        case .create:
            joiningLabel.text = "CREATING"
            welcomeLabel.text = "Your team is ready, and you're the first member. Welcome to the team!"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        
        self.finishJoinTeam()
    }
    
    func finishJoinTeam() {
        
        
        switch joinType! {
        case .invite(let invite): // send team invite response
            self.accept(invite: invite)

        case .create(let request, let session): // make the admin join the team
            self.createTeam(request: request, session: session)
        }
        
    }
    
    // for .create
    func createTeam(request:Request, session:Session) {
        
        do {
            
            var hashChainService = HashChainService(teamIdentity: teamIdentity)

            // 1. create the team.
            try hashChainService.createTeam { response in
                switch response {
                case .error(let error):
                    self.showCreateFailure(message: "Could not create team", error: error, request: request, session: session)
                    
                case .result(let updatedTeam):
                    self.teamIdentity.team = updatedTeam
                    hashChainService = HashChainService(teamIdentity: self.teamIdentity)
                    
                    do {
                        // save the team identity
                        try KeyManager.setTeam(identity: self.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    
                    // 2. send the create team response
                    let responseType = ResponseBody.createTeam(CreateTeamResponse(seed: self.teamIdentity.team.adminKeyPairSeed?.toBase64(), error: nil))
                    
                    let response = Response(requestID: request.id,
                                            endpoint: API.endpointARN ?? "",
                                            body: responseType,
                                            approvedUntil: Policy.approvedUntilUnixSeconds(for: session),
                                            trackingID: (Analytics.enabled ? Analytics.userID : "disabled"))
                    
                    do {
                        try TransportControl.shared.send(response, for: session)
                    } catch {
                        log("error sending response: \(error)", .error)
                        self.showWarning(title: "Error", body: "Couldn't respond with team info to \(session.pairing.displayName). \(error).")
                    }
                    
                    // 3. admin joins team
                    do {
                        let sshPublicKey = try KeyManager.sharedInstance().keyPair.publicKey.wireFormat()
                        let pgpPublicKey = try KeyManager.sharedInstance().loadPGPPublicKey(for: self.teamIdentity.email).packetData
                        
                        let admin = Team.MemberIdentity(publicKey: self.teamIdentity.keyPair.publicKey,
                                                        email: self.teamIdentity.email,
                                                        sshPublicKey: sshPublicKey,
                                                        pgpPublicKey: pgpPublicKey)
                        
                        try hashChainService.add(member: admin) { addResponse in
                            switch addResponse {
                            case .error(let error):
                                self.showCreateFailure(message: "Could not add you to the team", error: error, request: request, session: session)

                            case .result(let updatedTeam):
                                self.teamIdentity.team = updatedTeam
                                
                                // save the team identity again
                                try? KeyManager.setTeam(identity: self.teamIdentity)
              
                                self.showSuccess()
                            }
                        }

                    } catch { // add admin error
                        self.showCreateFailure(message: "Error trying to add you to the team", error: error, request: request, session: session)
                    }
                }
            }
            
            
        } catch { // create errror
            self.showCreateFailure(message: "Error trying to create your team", error: error, request: request, session: session)
        }
    }
    
    
    // for .invite
    func accept(invite:TeamInvite) {
        let hashChainService = HashChainService(teamIdentity: teamIdentity)

        do {
            try hashChainService.accept(invite: invite) { result in
                switch result {
                case .error(let error):
                    self.showFailure(by: JoinWorkflowError(error, action: "Team server error response on accept invite."))
                    
                case .result(let updatedTeam):
                    self.teamIdentity.team = updatedTeam
                    
                    // save the identity
                    do {
                        try KeyManager.setTeam(identity: self.teamIdentity)
                    } catch {
                        self.showFailure(by: JoinWorkflowError(error, action: "Could not save team identity."))
                        return
                    }
                    
                    self.showSuccess()
                }
            }
            
        } catch HashChainService.Errors.needNewestBlock {
            
            // we have a newer block
            // fetch new blocks and try again
            do {
                try hashChainService.getTeam(using: invite) { (result) in
                    switch result {
                    case .error(let error):
                        self.showFailure(by: JoinWorkflowError(error, action: "Server error getting newest block on retry."))
                        
                    // new team object, update and save it
                    case .result(let updatedTeam):
                        self.teamIdentity.team = updatedTeam
                        
                        // try join team again
                        self.finishJoinTeam()
                    }
                }
            } catch {
                self.showFailure(by: JoinWorkflowError(error, action: "Failed getting newest block on retry."))
            }
            
        } catch {
            self.showFailure(by: JoinWorkflowError(error, action: "Unexpected error. "))
        }
    }
    
    func showFailure(by error:Error) {
        dispatchMain  {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
                self.showWarning(title: "Error", body: "Could not accept team invitation. \(error).", then: {
                    self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
                })
            }
        }
    }
    
    func showCreateFailure(message:String, error:Error, request:Request, session:Session) {
        dispatchMain  {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
                self.showWarning(title: "Error", body: "\(message). \(error).", then: {
                    self.performSegue(withIdentifier: "dismissRedoInvitation", sender: nil)
                })
            }
        }
    }

    
    func showSuccess() {
        dispatchMain {
            UIView.animate(withDuration: 0.3, animations: {
                
                switch self.joinType! {
                case .invite:
                    self.joiningLabel.text = "JOINED"
                case .create:
                    self.joiningLabel.text = "CREATED"
                }
                
                self.arcView.alpha = 0
                self.resultViewUp.priority = 999
                self.resultViewDown.priority = 750
                self.view.layoutIfNeeded()
                
            }) { (_) in
                self.checkBox.toggleCheckState(true)
            }
        }
    }
    
    @IBAction func doneTapped() {
        self.performSegue(withIdentifier: "doneJoinTeam", sender: self)
    }
    
}
