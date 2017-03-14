//
//  RePairWarningController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 3/11/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation


class RePairWarningController:UIViewController {
    
    @IBOutlet weak var blurView:UIView!
    
    @IBOutlet weak var popupView:UIView!
    @IBOutlet weak var messageLabel:UILabel!
    
    @IBOutlet weak var upgradeLabel:UILabel!

    
    var scanController:KRScanController?
    
    var names:[String] = []
    
    private let baseMessage = "Kryptonite's pairing security just got a whole lot sweeter. Please upgrade kr and pair again with your device"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowOffset = CGSize(width: 0, height: 0)
        popupView.layer.shadowOpacity = 0.2
        popupView.layer.shadowRadius = 3
        popupView.layer.masksToBounds = false
        
        upgradeLabel.text = UpgradeMethod.current
        
        if names.isEmpty {
            log("re pair warning but no devices.", .error)
            self.dismiss(animated: true, completion: nil)
        } else if names.count == 1 {
            messageLabel.text = "\(baseMessage) \"\(names.first!.getDeviceName()).\""
        } else {
            let styledNames = names.map({ "\($0.getDeviceName())" })
            let styledNameString = "\"\(styledNames[0..<styledNames.count - 1].joined(separator: "\", \""))\" and \"\(styledNames.last!).\""
            
            messageLabel.text = "\(baseMessage)s: \(styledNameString)"
        }
        
    }
    
    @IBAction func readyToPairTapped() {
        
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        }
        
        let presenting = self.presentingViewController
        self.dismiss(animated: true, completion: {
            SessionManager.clearOldSessions()
            (presenting as? UITabBarController)?.selectedIndex = 1
        })
        
    }
}
