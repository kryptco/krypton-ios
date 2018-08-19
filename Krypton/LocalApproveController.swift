//
//  ApproveController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/23/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class LocalApproveController:UIViewController {
    
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
    
    var localU2FRequest:LocalU2FApproval?

    var isEnabled = true
    
    var category:String {
        return "local-u2f-request"
    }
    
    var detailController:ApproveDetailController?
    
    var presentingBaseController:UIViewController?
    
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 1.3) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        }
        
        if let appId = self.localU2FRequest?.request.appId {
            self.detailController?.setLocalU2FAuthenticateRequest(appId: appId)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    var options:[Option] {
        return [.yes, .no]
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
        
        guard let request = localU2FRequest else {
            log("no valid request or session", .error)
            self.dismissResponseFailed(errorMessage: "Invalid request")
            return
        }
        
        
        // set policy + post analytics
        switch option {
        case .yes:
            approve(option: option, request: request) { success in
                self.isEnabled = success
            }
            Analytics.postEvent(category: self.category, action: "foreground approve", label: "once")

        default:
            self.dismissReject()
            
        }
    }
    
    //MARK: Response
    func approve(option:Option, request:LocalU2FApproval, onResult:@escaping ((Bool) -> Void)) {
        
        // show selected option
        dispatchMain {
            self.swipeDownRejectGesture.isEnabled = false
            self.resultLabel.text = option.text.uppercased()
            
            UIView.animate(withDuration: 0.3, animations: {
                self.resultLabel.alpha = 1.0
                self.resultViewHeight.constant = self.optionsHeight.constant + 2
                self.view.layoutIfNeeded()
                self.optionsController?.update()
            })
        }
        
        // response may take a while, do this async
        dispatchAsync {
            do {
                
                let signedCallbackURL = try request.request.getSignedCallback(returnURL: request.returnURL,
                                                                              trustedFacets: request.trustedFacets)
                dispatchMain {
                    UIApplication.shared.open(signedCallbackURL, options: [:], completionHandler: { (success) in
                        // call result handler
                        dispatchMain { onResult(true) }
                        
                        // show check mark success
                        dispatchMain {
                            UIView.animate(withDuration: 0.25, animations: {
                                self.arcView.alpha = 0
                            })
                            self.checkBox.toggleCheckState(true)
                            dispatchAfter(delay: 2.0) {
                                self.animateDismiss(allowed: true)
                            }
                        }
                    })
                }
                
            } catch {
                log("response error \(error)", .error)
                
                // hide the selected option and show error
                self.showWarning(title: "Error", body: "Could not approve request. \(error)") {
                    dispatchMain {
                        UIView.animate(withDuration: 0.5, animations: {
                            self.resultLabel.text = ""
                            self.resultLabel.alpha = 0
                            self.resultViewHeight.constant = 0
                            self.view.layoutIfNeeded()
                            self.optionsController?.update()
                            
                        }, completion: { (_) in
                            onResult(false)
                        })
                    }
                }
                
                return
            }
            
        }
        
    }
    
    @IBAction func dismissReject() {
        Analytics.postEvent(category: category, action: "foreground reject")
        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
                
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
        
        let presenting = self.presentingBaseController
        self.dismiss(animated: true, completion: {
            (presenting as? KRBase)?.approveControllerDismissed(allowed: allowed)
        })
    }
}






