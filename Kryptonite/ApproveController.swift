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
    @IBOutlet weak var deviceLabel:UILabel!
    @IBOutlet weak var requestView:UIView!

    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var swipeDownRejectGesture:UIGestureRecognizer!
    

    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewHeight:NSLayoutConstraint!
    @IBOutlet weak var resultLabel:UILabel!

    var rejectColor = UIColor.reject
    
    var request:Request?
    var session:Session?
    
    var isEnabled = true
    
    var category:String {
        return request?.body.analyticsCategory ?? "unknown-request"
    }
    
    var detailController:ApproveDetailController?

    // options
    @IBOutlet weak var optionView:UIView!
    @IBOutlet weak var optionsHeight:NSLayoutConstraint!
    var optionsController:ApproveOptionsController?
    
    typealias Option = ApproveOptionsController.Option
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resultLabel.alpha = 0
        resultViewHeight.constant = 0
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.shadowOpacity = 0.2
        contentView.layer.shadowRadius = 3
        contentView.layer.masksToBounds = false
        
        optionView.layer.cornerRadius = 16
        
        checkBox.animationDuration = 1.0
        
        if let session = session {
            deviceLabel.text = session.pairing.displayName.uppercased()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 1.3) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
        
        self.detailController?.set(request: self.request)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    var options:[Option] {
        guard let requestBody = request?.body else {
            return [.reject]
        }
        
        var responseOptions:[Option] = []
        
        switch requestBody {
        case .ssh(let signRequest):
            if let _ = signRequest.verifiedUserAndHostAuth {
                responseOptions = [.allowOnce, .allowThis, .allowAll]
            } else {
                
                // don't show the allow-all option unless it's enabled
                if let session = self.session, Policy.SessionSettings(for: session).settings.shouldPermitUnknownHostsAllowed {
                    responseOptions = [.allowOnce, .allowAll]
                } else {
                    responseOptions = [.allow]
                }
            }
        case .git:
            responseOptions = [.allowOnce, .allowAll]
        
        case .hosts, .me, .unpair, .noOp:
            break
        }
        
        return responseOptions + [.reject]
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let optionsController = segue.destination as? ApproveOptionsController {
            optionsController.options = self.options
            optionsController.onSelect = onSelect
            optionsController.doAdjustHeight = adjustSize
            self.optionsController = optionsController
            optionsController.tableView.reloadData()
        }
        else if let detail = segue.destination as? ApproveDetailController
        {
            self.detailController = detail
            detail.view.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    func adjustSize(to height:CGFloat) {
        optionsHeight.constant = height
        self.view.layoutIfNeeded()
    }
    
    // MARK: Option Selection
    
    func onSelect(option:Option) {
        guard isEnabled else {
            return
        }
        
        isEnabled = false

        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        
        guard let request = request, let session = session else {
            log("no valid request or session", .error)
            self.dismissResponseFailed(errorMessage: "Invalid request or session")
            return
        }
        
        let policySession = Policy.SessionSettings(for: session)

    
        // set policy + post analytics
        switch option {
        case .allow, .allowOnce:
            let success = approve(option: option, request: request, session: session)
            
            guard success else {
                isEnabled = true
                return
            }

            Analytics.postEvent(category: category, action: "foreground approve", label: "once")
            
        case .allowThis:
            let success = approve(option: option, request: request, session: session)
            
            guard success else {
                isEnabled = true
                return
            }

            Analytics.postEvent(category: category, action: "foreground approve", label: "host-and-time", value: UInt(Policy.Interval.threeHours.rawValue))

            if case .ssh(let signRequest) = request.body, let userAndHost = signRequest.verifiedUserAndHostAuth {
                policySession.allowThis(userAndHost: userAndHost, for: Policy.Interval.threeHours.seconds)
            }


        case .allowAll:
            let success = approve(option: option, request: request, session: session)
            
            guard success else {
                isEnabled = true
                return
            }
            
            policySession.allowAll(request: request, for: Policy.Interval.threeHours.seconds)

            Analytics.postEvent(category: category, action: "foreground approve", label: "time", value: UInt(Policy.Interval.threeHours.rawValue))


        case .reject:
            self.dismissReject()
            Analytics.postEvent(category: category, action: "foreground reject")
        }
    }
    
    //MARK: Response
    func approve(option:Option, request:Request, session:Session) -> Bool {
        do {
            let resp = try Silo.shared.lockResponseFor(request: request, session: session, allowed: true)
            try TransportControl.shared.send(resp, for: session)
            
            if let errorMessage = resp.body.error {
                self.dismissResponseFailed(errorMessage: errorMessage)
                return false
            }
            
        } catch (let e) {
            log("send error \(e)", .error)
            self.showWarning(title: "Error", body: "Could not approve request. \(e)")
            return false
        }
        
        swipeDownRejectGesture.isEnabled = false

        self.resultLabel.text = option.text.uppercased()
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.resultLabel.alpha = 1.0
            self.arcView.alpha = 0
            self.resultViewHeight.constant = self.optionsHeight.constant + 2
            self.view.layoutIfNeeded()
            self.optionsController?.update()
    
            
        }) { (_) in
            
            self.checkBox.toggleCheckState(true)
                dispatchAfter(delay: 2.0) {
                    self.animateDismiss(allowed: true)
                }
        }
        
        return true
    }
    
    @IBAction func dismissReject() {
        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        
        do {
            if let request = request, let session = session {
                let resp = try Silo.shared.lockResponseFor(request: request, session: session, allowed: false)
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
            self.resultViewHeight.constant = self.optionsHeight.constant + 2
            self.view.layoutIfNeeded()

            
        }) { (_) in
            self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            dispatchAfter(delay: 2.0) {
                self.animateDismiss()
            }
        }
        
    }
    

    func dismissResponseFailed(errorMessage:String) {

        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()

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
            self.resultViewHeight.constant = self.optionsHeight.constant + 2
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
            (presenting as? KRBase)?.approveControllerDismissed(allowed: allowed)
        })
    }
}





