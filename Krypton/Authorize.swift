//
//  Policy+UI.swift
//  Krypton
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

extension Request {
    func approveController(for session:Session, from presenter:UIViewController) -> UIViewController? {
        
        switch self.body {
        case .ssh, .git, .decryptLog, .teamOperation, .readTeam:
            let controller = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "ApproveController") as? ApproveController
            controller?.session = session
            controller?.request = self
            controller?.presentingBaseController = presenter
            
            return controller

        case .hosts:
            let (subtitle, body) = notificationDetails()
            let controller = UIAlertController(title: "Request: \(subtitle)", message: body, preferredStyle: UIAlertControllerStyle.actionSheet)
            controller.addAction(UIAlertAction(title: "Allow", style: UIAlertActionStyle.default, handler: { (_) in
                do {
                    let resp = try Silo.shared().lockResponseFor(request: self, session: session, allowed: true)
                    try TransportControl.shared.send(resp, for: session)
                } catch {
                    log("error allowing: \(error)")
                }
            }))
            controller.addAction(UIAlertAction(title: "Reject", style: UIAlertActionStyle.destructive, handler: { (_) in
                do {
                    let resp = try Silo.shared().lockResponseFor(request: self, session: session, allowed: false)
                    try TransportControl.shared.send(resp, for: session)

                } catch {
                    log("error rejecting: \(error)")
                }
            }))
            
            return controller
                
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
        guard let approvalController = request.approveController(for: session, from: self) else {
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
