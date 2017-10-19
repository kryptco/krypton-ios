//
//  Policy+UI.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

extension Request {
    func approveController(for session:Session) -> UIViewController? {
        
        switch self.body {
        case .ssh:
            let sshApprove = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "SSHApproveController") as? SSHApproveController
            sshApprove?.session = session
            sshApprove?.request = self
            
            return sshApprove
            
        case .git(let gitSign):
            switch gitSign.git {
            case .commit:
                let commitApprove = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "CommitApproveController") as? CommitApproveController
                commitApprove?.session = session
                commitApprove?.request = self
                
                return commitApprove

            case .tag:
                let tagApprove = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "TagApproveController") as? TagApproveController
                tagApprove?.session = session
                tagApprove?.request = self
                
                return tagApprove
            }
        case .createTeam:
            let teamLoad =  Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamLoadController") as? TeamLoadController
            teamLoad?.joinType = TeamJoinType.create(self, session)
            
            return teamLoad
        
        case .decryptLog, .teamOperation, .readTeam:
            let teamApprove = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "TeamApproveController") as? TeamApproveController
            teamApprove?.session = session
            teamApprove?.request = self
            
            return teamApprove

        case .me, .unpair, .noOp:
            return nil
        }
    }
    
    var autoApproveDisplay:String? {
        switch self.body {
        case .ssh(let sshRequest):
            return sshRequest.display
        case .git(let gitSign):
            return gitSign.git.shortDisplay

        default:
            return nil
        }
    }
}

extension UIViewController {
    
    
    func requestUserAuthorization(session:Session, request:Request) {
        
        // remove pending
        Policy.removePendingAuthorization(session: session, request: request)
        
        // proceed to show approval request
        guard let approvalController = request.approveController(for: session) else {
            log("nil approve controller", .error)
            return
        }
        
        approvalController.modalTransitionStyle = UIModalTransitionStyle.coverVertical
        approvalController.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        
        dispatchMain {
            if self.presentedViewController is AutoApproveController {
                self.presentedViewController?.dismiss(animated: false, completion: {
                    self.present(approvalController, animated: true, completion: nil)
                })
            } else {
                self.present(approvalController, animated: true, completion: nil)
            }
        }
    }
    
    func showApprovedRequest(session:Session, request:Request) {
        
        // don't show if user is asked to approve manual
        guard self.presentedViewController is ApproveController == false
            else {
                return
        }
        
        // remove pending
        Policy.removePendingAuthorization(session: session, request: request)
        
        // proceed to show auto approval
        let autoApproveController = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "AutoApproveController")
        autoApproveController.modalTransitionStyle = UIModalTransitionStyle.coverVertical
        autoApproveController.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        
        (autoApproveController as? AutoApproveController)?.deviceName = session.pairing.displayName.uppercased()
        (autoApproveController as? AutoApproveController)?.command = request.autoApproveDisplay        
        
        dispatchMain {
            if self.presentedViewController is AutoApproveController {
                self.presentedViewController?.dismiss(animated: false, completion: {
                    self.present(autoApproveController, animated: true, completion: nil)
                })
            } else {
                self.present(autoApproveController, animated: true, completion: nil)
            }
        }
    }
    
    func showFailedResponse(errorMessage:String, session:Session) {
        
        // don't show if user is asked to approve manual
        guard self.presentedViewController is ApproveController == false
            else {
                return
        }
        
        // proceed to show auto approval
        let autoApproveController = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "AutoApproveController")
        autoApproveController.modalTransitionStyle = UIModalTransitionStyle.coverVertical
        autoApproveController.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        
        (autoApproveController as? AutoApproveController)?.deviceName = session.pairing.displayName.uppercased()
        (autoApproveController as? AutoApproveController)?.errorMessage = errorMessage
        
        
        dispatchMain {
            if self.presentedViewController is AutoApproveController {
                self.presentedViewController?.dismiss(animated: false, completion: {
                    self.present(autoApproveController, animated: true, completion: nil)
                })
            } else {
                self.present(autoApproveController, animated: true, completion: nil)
            }
        }
    }
}
