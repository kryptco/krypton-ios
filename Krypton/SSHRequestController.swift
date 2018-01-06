//
//  SSHApproveController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class SSHRequestController:UIViewController {
    
    @IBOutlet weak var userAndHostLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func set(signRequest:SignRequest) {
        userAndHostLabel.text = signRequest.display
    }
    
}
