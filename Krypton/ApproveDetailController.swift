//
//  ApproveDetailController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class ApproveDetailController: UIViewController {
    @IBOutlet weak var sshContainerView:UIView!
    @IBOutlet weak var commitContainerView:UIView!
    @IBOutlet weak var tagContainerView:UIView!
    @IBOutlet weak var teamOpContainerView:UIView!
    @IBOutlet weak var errorContainerView:UIView!

    var sshController:SSHRequestController?
    var commitController:GitCommitRequestController?
    var tagController:GitTagRequestController?
    var teamOpController:TeamOpRequestController?
    var errorController:ErrorRequestController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    

    func set(request:Request?) {
        
        guard let request = request else {
            errorController?.set(errorMessage: "Empty Request.")
            removeAllBut(view: errorContainerView)
            return
        }
        
        struct NoTeamError:Error {}
        
        do {
            switch request.body {
            case .ssh(let signRequest):
                sshController?.set(signRequest: signRequest)
                removeAllBut(view: sshContainerView)
                
            case .git(let gitSignRequest):
                switch gitSignRequest.git {
                case .commit(let commit):
                    commitController?.set(commit: commit)
                    removeAllBut(view: commitContainerView)
                    
                case .tag(let tag):
                    tagController?.set(tag: tag)
                    removeAllBut(view: tagContainerView)
                }
            case .readTeam(let teamReadRequest):
                guard let name = (try IdentityManager.getTeamIdentity()?.dataManager.withTransaction { return try $0.fetchTeam().name })
                else {
                    throw NoTeamError()
                }
                
                teamOpController?.set(teamName: name, readTeamRequest: teamReadRequest)
                removeAllBut(view: teamOpContainerView)

            case .teamOperation(let teamOpRequest):
                
                guard let identity = try IdentityManager.getTeamIdentity() else {
                    throw NoTeamError()
                }
                
                
                do {
                    try identity.dataManager.withTransaction {
                        try teamOpController?.set(identity: identity, teamOperationRequest: teamOpRequest, dataManager: $0)
                    }

                    removeAllBut(view: teamOpContainerView)
                } catch TeamOpRequestController.TeamOperationError.noSuchMember {
                    errorController?.set(errorMessage: "No Such Member: specified identity is not a nember of the team.")
                    removeAllBut(view: errorContainerView)
                } catch TeamOpRequestController.TeamOperationError.noSuchAdmin {
                    errorController?.set(errorMessage: "No Such Admin: specified member is not an admin of the team.")
                    removeAllBut(view: errorContainerView)
                } catch {
                    errorController?.set(errorMessage: "Unknown error: \(error).")
                    removeAllBut(view: errorContainerView)
                }

            case .decryptLog(let logDecrypt):
                guard let name = (try IdentityManager.getTeamIdentity()?.dataManager.withTransaction { return try $0.fetchTeam().name })
                else {
                    throw NoTeamError()
                }

                teamOpController?.set(teamName: name, decryptLogRequest: logDecrypt)
                removeAllBut(view: teamOpContainerView)

            case .hosts, .me, .noOp, .unpair:
                errorController?.set(errorMessage: "Unhandled request type.")
                removeAllBut(view: errorContainerView)
            }

        } catch is NoTeamError {
            errorController?.set(errorMessage: "No Team Identity.")
            removeAllBut(view: errorContainerView)

        } catch {
            errorController?.set(errorMessage: "Unknown: \(error)")
            removeAllBut(view: errorContainerView)

        }

    }
    func removeAllBut(view:UIView) {
        for v in [sshContainerView, commitContainerView, tagContainerView, teamOpContainerView, errorContainerView] {
            guard v != view else {
                continue
            }
            
            v?.removeFromSuperview()
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let ssh = segue.destination as? SSHRequestController {
            self.sshController = ssh
        } else if let commit = segue.destination as? GitCommitRequestController {
            self.commitController = commit
        } else if let tag = segue.destination as? GitTagRequestController {
            self.tagController = tag
        } else if let error = segue.destination as? ErrorRequestController {
            self.errorController = error
        } else if let teamOp = segue.destination as? TeamOpRequestController {
            self.teamOpController = teamOp
        }
        
        segue.destination.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
}
