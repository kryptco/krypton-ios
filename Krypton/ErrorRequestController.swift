//
//  ErrorRequestController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class ErrorRequestController:UIViewController {
    
    @IBOutlet weak var errorLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func set(errorMessage:String) {
        errorLabel.text = errorMessage
    }
    
}
