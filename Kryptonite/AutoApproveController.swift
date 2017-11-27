//
//  AutoApproveController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 5/22/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class AutoApproveController:UIViewController {
    @IBOutlet weak var deviceLabel:UILabel!
    @IBOutlet weak var typeLabel:UILabel!
    @IBOutlet weak var valueLabel:UILabel!
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var contentView:UIView!
    
    @IBOutlet weak var commandView:UIView!
    @IBOutlet weak var deviceView:UIView!
    
    
    var deviceName:String?
    var errorMessage:String?
    
    var type:String?
    var value:String?
    
    
    var rejectColor = UIColor.reject
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.shadowOpacity = 0.3
        contentView.layer.shadowRadius = 3
        contentView.layer.masksToBounds = false
        
        typeLabel.text = "\(type ?? "unknown request type")".uppercased()
        
        deviceLabel.text = deviceName
        if let error = errorMessage  {
            valueLabel.text = error
            
            commandView.backgroundColor = rejectColor
            deviceView.backgroundColor = rejectColor
            checkBox.secondaryTintColor = rejectColor
        } else {
            valueLabel.text = "\(value ?? "unknown error")"
        }
        
        checkBox.animationDuration = 1.0
        
        checkBox.checkmarkLineWidth = 2.0
        checkBox.stateChangeAnimation = .spiral
        checkBox.boxLineWidth = 2.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()

        if let _ = errorMessage {
            checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)
        } else {
            checkBox.setCheckState(M13Checkbox.CheckState.checked, animated: true)
        }
        dispatchAfter(delay: 4.0) {
            self.dismiss()
        }
    }
    
    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: {
        })
    }
}
