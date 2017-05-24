//
//  ApproveController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/23/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class ApproveController:UIViewController {
    
    @IBOutlet weak var contentView:UIView!
    
    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewHeight:NSLayoutConstraint!
    @IBOutlet weak var resultLabel:UILabel!

    
    @IBOutlet weak var deviceLabel:UILabel!
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var swipeDownRejectGesture:UIGestureRecognizer!

    var rejectColor = UIColor.reject
    
    var heightCover:CGFloat = 234.0
    
    var request:Request?
    var session:Session?
    
    var isEnabled = true
    
    var defaultCategory = "signature"
    
    var category:String {
        return defaultCategory
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.shadowOpacity = 0.2
        contentView.layer.shadowRadius = 3
        contentView.layer.masksToBounds = false
        
        checkBox.animationDuration = 1.0
        
        resultViewHeight.constant = 0
        resultLabel.alpha = 0
        
        if let session = session {
            deviceLabel.text = session.pairing.displayName.uppercased()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 1.3) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        //arcView.timeoutProgress(lineWidth: checkBox.checkmarkLineWidth, seconds: Properties.requestTimeTolerance)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    

    
    
    //MARK: Response
    @IBAction func approveOnce() {
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        guard let request = request, let session = session, isEnabled else {
            log("no valid request or session", .error)
            return
        }
        
        isEnabled = false
        
        do {
            let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: true)
            try TransportControl.shared.send(resp, for: session)
            
            if let errorMessage = resp.sign?.error {
                isEnabled = true
                self.dismissResponseFailed(errorMessage: errorMessage)
                return
            }
            
        } catch (let e) {
            isEnabled = true
            log("send error \(e)", .error)
            self.showWarning(title: "Error", body: "Could not approve request. \(e)")
            return
        }
        
        swipeDownRejectGesture.isEnabled = false

        self.resultLabel.text = "Allow once".uppercased()
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.resultLabel.alpha = 1.0
            self.arcView.alpha = 0
            self.resultViewHeight.constant = self.heightCover
            self.view.layoutIfNeeded()
            
            
        }) { (_) in
            
            self.checkBox.toggleCheckState(true)
                dispatchAfter(delay: 2.0) {
                    self.animateDismiss(allowed: true)
                }
        }

        Analytics.postEvent(category: category, action: "foreground approve", label: "once")

    }
    
    @IBAction func approveThreeHours() {
        
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        guard let request = request, let session = session, isEnabled else {
            log("no valid request or session", .error)
            return
        }
        
        isEnabled = false
        
        do {
            Policy.allow(session: session, for: Policy.Interval.threeHours)
            let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: true)
            try TransportControl.shared.send(resp, for: session)
            
            if let errorMessage = resp.sign?.error {
                isEnabled = true
                self.dismissResponseFailed(errorMessage: errorMessage)
                return
            }
            
        } catch (let e) {
            isEnabled = true
            log("send error \(e)", .error)
            self.showWarning(title: "Error", body: "Could not approve request. \(e)")
            return
        }
        
        swipeDownRejectGesture.isEnabled = false

        self.resultLabel.text = "Allow for 3 hours".uppercased()
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.resultLabel.alpha = 1.0
            self.arcView.alpha = 0
            self.resultViewHeight.constant = self.heightCover
            self.view.layoutIfNeeded()
            
            
        }) { (_) in
            dispatchMain{ self.checkBox.toggleCheckState(true) }
            dispatchAfter(delay: 2.0) {
                self.animateDismiss(allowed: true)
            }
        }

        Analytics.postEvent(category: category, action: "foreground approve", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))

    }
    
    @IBAction func dismissReject() {
        
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        guard isEnabled else {
            return
        }
        
        isEnabled = false
        
        do {
            if let request = request, let session = session {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: false)
                try TransportControl.shared.send(resp, for: session)
            }
            
        } catch (let e) {
            log("send error \(e)", .error)
        }
        
        self.resultLabel.text = "Reject".uppercased()
        self.resultView.backgroundColor = rejectColor
        self.checkBox.secondaryCheckmarkTintColor = rejectColor
        self.checkBox.tintColor = rejectColor
        
        UIView.animate(withDuration: 0.3, animations: {
            self.resultLabel.alpha = 1.0
            self.arcView.alpha = 0
            self.resultViewHeight.constant = self.heightCover
            self.view.layoutIfNeeded()
            
        }) { (_) in
            self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            dispatchAfter(delay: 2.0) {
                self.animateDismiss()
            }
        }
        
        Analytics.postEvent(category: category, action: "foreground reject")
        
    }
    

    func dismissResponseFailed(errorMessage:String) {

        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        guard isEnabled else {
            return
        }
        
        isEnabled = false
        
        self.resultLabel.text = errorMessage.uppercased()
        self.resultView.backgroundColor = rejectColor
        self.checkBox.secondaryCheckmarkTintColor = rejectColor
        self.checkBox.tintColor = rejectColor
        
        UIView.animate(withDuration: 0.3, animations: {
            self.resultLabel.alpha = 1.0
            self.arcView.alpha = 0
            self.resultViewHeight.constant = self.heightCover
            self.view.layoutIfNeeded()
            
        }) { (_) in
            self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            dispatchAfter(delay: 2.0) {
                self.animateDismiss()
            }
        }
        
        let errorLabel = HostMistmatchError.isMismatchErrorString(err: errorMessage) ? "host mistmatch" : "crypto error"
        Analytics.postEvent(category: category, action: "failed foreground approve", label: errorLabel)
    }
    
    func animateDismiss(allowed:Bool = false) {
        UIView.animate(withDuration: 0.1) {
            self.view.backgroundColor = UIColor.clear
        }
        
        let presenting = self.presentingViewController
        self.dismiss(animated: true, completion: {
            presenting?.approveControllerDismissed(allowed: allowed)
        })
    }
}

class SSHApproveController:ApproveController {
    
    @IBOutlet weak var commandLabel:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let sshSign = request?.sign {
            commandLabel.text = sshSign.display
        } else {
            commandLabel.text = "Unknown"
        }
    }

}

class CommitApproveController:ApproveController {
    
    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var authorLabel:UILabel!
    @IBOutlet weak var authorDateLabel:UILabel!
    
    @IBOutlet weak var committerLabel:UILabel!

    override var category:String {
        return "git-commit-signtaure"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let gitSign = request?.gitSign else {
            clear()
            return
        }
        
        switch gitSign.git {
        case .commit(let commit):
            messageLabel.text = commit.messageString
            
            if commit.author == commit.committer {
                let (author, date) = commit.author.userIdAndDateString
                authorLabel.text = author
                authorDateLabel.text = date
                committerLabel.text = ""
            } else {
                let (author, _) = commit.author.userIdAndDateString
                let (committer, committerDate) = commit.committer.userIdAndDateString

                authorLabel.text = "A: " + author
                committerLabel.text = "C: " + committer
                authorDateLabel.text = committerDate
            }
            
        
            
        default:
            clear()
            return
        }

    }

    func clear() {
        messageLabel.text = "--"
        authorLabel.text = "--"
        authorDateLabel.text = "--"
        committerLabel.text = "--"
    }

}

class TagApproveController:ApproveController {
    
    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var objectHashLabel:UILabel!
    @IBOutlet weak var tagLabel:UILabel!
    @IBOutlet weak var taggerLabel:UILabel!
    @IBOutlet weak var taggerDate:UILabel!
    
    override var category:String {
        return "git-tag-signtaure"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let gitSign = request?.gitSign else {
            clear()
            return
        }
        
        switch gitSign.git {
        case .tag(let _):
            break
            
        default:
            clear()
            return
        }
        
    }
    
    func clear() {
        messageLabel.text = "--"
        objectHashLabel.text = "--"
        tagLabel.text = "--"
        taggerLabel.text = "--"
        taggerDate.text = "--"
    }
    
}


