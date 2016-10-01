//
//  SessionsEmptyController.swift
//  krSSH
//
//  Created by Alex Grinman on 10/1/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class SessionsEmptyController:KRBaseController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard PeerManager.shared.all.isEmpty else {
            dismiss(animated: true, completion: nil)
            return
        }
    }
    
    
    
    @IBAction func addDevice() {
        
    }
}
