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

    var session:Session?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandView.layer.shadowColor = UIColor.black.cgColor
        commandView.layer.shadowOffset = CGSize(width: 0, height: 0)
        commandView.layer.shadowOpacity = 0.175
        commandView.layer.shadowRadius = 3
        commandView.layer.masksToBounds = false

        Onboarding.isActive = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = session {
            sessionLabel.text = "\(session.pairing.displayName.uppercased())"
        }
        
 

    }

}
