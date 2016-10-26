//
//  PairApproveController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/26/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import LocalAuthentication

class PairApproveController: UIViewController {
    
    @IBOutlet weak var blurView:UIView!
    
    @IBOutlet weak var popupView:UIView!
    @IBOutlet weak var deviceLabel:UILabel!
    
    @IBOutlet weak var result:UIImageView!
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!

    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewHeight:NSLayoutConstraint!
    @IBOutlet weak var resultLabel:UILabel!

    var heightCover:CGFloat = 178.0

    static var isAuthenticated:Bool = false
    
    var rejectColor = UIColor(hex: 0xFF6361)

    var pairing:Pairing?

    enum ResultImage:String {
        case check = "check"
        case x = "x"
        
        var image:UIImage? {
            return UIImage(named: self.rawValue)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowOffset = CGSize(width: 0, height: 0)
        popupView.layer.shadowOpacity = 0.2
        popupView.layer.shadowRadius = 3
        popupView.layer.masksToBounds = false

        resultViewHeight.constant = 0
        resultLabel.alpha = 0
        checkBox.animationDuration = 1.0
        
        if let pairing = pairing {
            deviceLabel.text = pairing.displayName.uppercased()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: Accept Reject
    
    @IBAction func acceptTapped() {
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
    }
    
    @IBAction func rejectTapped() {
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        Analytics.postEvent(category: "device", action: "pair", label: "reject")
        
        self.checkBox.secondaryCheckmarkTintColor = rejectColor
        self.checkBox.tintColor = rejectColor
        
        self.resultLabel.text = "Cancelled".uppercased()
        self.resultView.backgroundColor = rejectColor

        UIView.animate(withDuration: 0.3, animations: {
            self.arcView.alpha = 0
            self.resultLabel.alpha = 1.0
            self.resultViewHeight.constant = self.heightCover
            self.view.layoutIfNeeded()

        }) { (_) in
            self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            dispatchAfter(delay: 2.0) {
                self.hidePopup(success: false)
            }
        }
        

    }
    
    
    //MARK: Approve Scanned
    
    func approve(pairing:Pairing) {
        authenticate(completion: { (success) in
            guard success else {
                dispatchMain {
                    self.hidePopup(success: false)
                }
                
                self.showWarning(title: "Authentication Failed", body: "Authentication is needed to pair to a new device.")
                
                return
            }
            
            do {
                
                if let existing = SessionManager.shared.get(deviceName: pairing.name) {
                    SessionManager.shared.remove(session: existing)
                    Silo.shared.remove(session: existing)
                    Analytics.postEvent(category: "device", action: "pair", label: "existing")
                } else {
                    Analytics.postEvent(category: "device", action: "pair", label: "new")
                }
                
                let session = try Session(pairing: pairing)
                SessionManager.shared.add(session: session)
                Silo.shared.add(session: session)
                Silo.shared.startPolling(session: session)
            }
            catch let e {
                log("error creating session: \(e)", .error)
            }
            
            dispatchMain {
                self.hidePopup(success: true)
            }
            
            dispatchAfter(delay: 1.0, task: {
                dispatchMain {
                    self.parent?.tabBarController?.selectedIndex = 2
                }
            })
        })

    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        let reason = "Authentication is needed to pair with a new machine."
        
        var err:NSError?
        guard context.canEvaluatePolicy(policy, error: &err) else {
            log("cannot eval policy: \(err?.localizedDescription ?? "unknown err")", .error)
            completion(true)
            
            return
        }
        
        
        dispatchMain {
            context.evaluatePolicy(policy, localizedReason: reason, reply: { (success, policyErr) in
                completion(success)
            })
            
        }
        
    }

    
    //MARK: Hiding popup
    
    func hidePopup(success:Bool) {
        if success {
            self.result.image = ResultImage.check.image
        } else {
            self.result.image = ResultImage.x.image
        }
        
        UIView.animate(withDuration: 0.5, animations: { 
            self.popupView.alpha = 0
        }) { (_) in
            dispatchAfter(delay: 1.0, task: {
                self.dismiss(animated: true, completion: { 
                    (self.parent as? PairController)?.scanViewController?.canScan = true
                })
            })
        }
        
    }
    

}
