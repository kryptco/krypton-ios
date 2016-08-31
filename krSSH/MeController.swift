//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class MeController: UITableViewController {

    @IBOutlet var keyIcon:UILabel!
    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet var tagIcon:UILabel!
    @IBOutlet var tagLabel:UILabel!
    
    @IBOutlet var identiconView:UIImageView!

    @IBOutlet var copyButton:UIButton!
    @IBOutlet var linkButton:UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup icons and borders
        keyIcon.FAIcon = FAType.FAKey
        tagIcon.FAIcon = FAType.FATag
        
        
        
        copyButton.setBorder(color: UIColor.app, borderWidth: 1.0)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}
