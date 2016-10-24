//
//  ApproveController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/23/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class ApproveController:UIViewController {
    
    @IBOutlet weak var contentView:UIView!
    
    @IBOutlet weak var resultView:UIView!
    @IBOutlet weak var resultViewHeight:NSLayoutConstraint!
    @IBOutlet weak var resultLabel:UILabel!

    @IBOutlet weak var checkBox:M13Checkbox!

    var rejectColor = UIColor(hex: 0xFF6361)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.shadowOpacity = 0.175
        contentView.layer.shadowRadius = 3
        contentView.layer.masksToBounds = false
        
        checkBox.animationDuration = 1.0
        
        resultViewHeight.constant = 0
        resultLabel.alpha = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIView.animate(withDuration: 1.0) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    @IBAction func approveOnce() {
        
        self.resultLabel.text = "Allowed once".uppercased()
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.resultLabel.alpha = 1.0
            
            self.resultViewHeight.constant = 152
            self.view.layoutIfNeeded()
            
            
        }) { (_) in
            self.checkBox.toggleCheckState(true)
                dispatchAfter(delay: 1.5) {
                    self.animateDismiss()
                }
        }
        

    }
    
    @IBAction func approveOneHour() {
        
        self.resultLabel.text = "Allowed for 1 hour".uppercased()
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.resultLabel.alpha = 1.0
            
            self.resultViewHeight.constant = 152
            self.view.layoutIfNeeded()
            
            
        }) { (_) in
            self.checkBox.toggleCheckState(true)
            dispatchAfter(delay: 1.5) {
                self.animateDismiss()
            }
        }

    }
    
    
    
    @IBAction func dismissReject() {
        
        self.resultLabel.text = "Rejected".uppercased()
        self.resultView.backgroundColor = rejectColor
        self.checkBox.secondaryCheckmarkTintColor = rejectColor
        self.checkBox.tintColor = rejectColor
        
        UIView.animate(withDuration: 0.3, animations: {
            self.resultLabel.alpha = 1.0
            self.resultViewHeight.constant = 152
            self.view.layoutIfNeeded()
            
        }) { (_) in
            self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
            dispatchAfter(delay: 1.5) {
                self.animateDismiss()
            }
        }

    }
    
    func animateDismiss() {
        UIView.animate(withDuration: 0.1) {
            self.view.backgroundColor = UIColor.clear
        }
        
        self.dismiss(animated: true, completion: nil)
    }
}
