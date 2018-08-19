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
        case .ssh, .git, .decryptLog, .teamOperation, .readTeam, .u2fAuthenticate, .u2fRegister:
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
}

extension UIViewController {
    
    func requestLocalU2FAuthorization(localU2FApprovalRequest:LocalU2FApproval) {
        let controller = Resources.Storyboard.Approval.instantiateViewController(withIdentifier: "LocalApproveController") as! LocalApproveController
        controller.localU2FRequest = localU2FApprovalRequest
        controller.presentingBaseController = self
        controller.modalTransitionStyle = UIModalTransitionStyle.coverVertical
        controller.modalPresentationStyle = UIModalPresentationStyle.overFullScreen

        dispatchMain {
            self.present(controller, animated: true, completion: nil)
        }
    }
    
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
            self.present(approvalController, animated: true, completion: nil)
        }
    }
}
