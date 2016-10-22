//
//  SessionsEmptyController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class SessionsEmptyController:KRBaseController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard SessionManager.shared.all.isEmpty else {
            dismiss(animated: true, completion: nil)
            return
        }
    }
    
    
    
    @IBAction func addDevice() {
        (self.parent?.parent as? UITabBarController)?.selectedIndex = 1
    }
}
