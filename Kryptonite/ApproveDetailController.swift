//
//  ApproveDetailController.swift
//  Kryptonite
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
    @IBOutlet weak var errorContainerView:UIView!

    var sshController:SSHRequestController?
    var commitController:GitCommitRequestController?
    var tagController:GitTagRequestController?
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
        case .hosts, .me, .noOp, .unpair:
            errorController?.set(errorMessage: "Unhandled request type.")
            removeAllBut(view: errorContainerView)
        }

    }
    func removeAllBut(view:UIView) {
        //errorContainerView.isHidden = true
        for v in [sshContainerView, commitContainerView, tagContainerView, errorContainerView] {
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
        }
        
        segue.destination.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
}
