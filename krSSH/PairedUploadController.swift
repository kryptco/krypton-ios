//
//  PairedUploadController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class PairedUploadController:KRBaseController {
    
    @IBOutlet weak var sessionLabel:UILabel!
    @IBOutlet weak var commandView:UIView!

    @IBOutlet weak var githubLabel:UILabel!
    @IBOutlet weak var githubCommandView:UIView!

    @IBOutlet weak var skipButton:UIButton!

    var session:Session?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for v in [commandView, githubCommandView] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
        
        Onboarding.isActive = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = session {
            sessionLabel.text = "\(session.pairing.displayName.uppercased())"
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        
        return true
    }
    
    

}
