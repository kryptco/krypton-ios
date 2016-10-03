//
//  PairedUploadController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class PairedUploadController:KRBaseController {
    
    @IBOutlet weak var sessionLabel:UILabel!
    var session:Session?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = session {
            sessionLabel.text = "\(session.pairing.name)"
        }
        
 

    }

}
