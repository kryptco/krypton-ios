//
//  TagApproveController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class GitTagRequestController:UIViewController {
    
    var request:Request?
    
    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var objectHashLabel:UILabel!
    @IBOutlet weak var tagLabel:UILabel!
    @IBOutlet weak var taggerLabel:UILabel!
    @IBOutlet weak var taggerDate:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func set(tag:TagInfo) {
        messageLabel.text = tag.messageString
        objectHashLabel.text = tag.objectShortHash
        tagLabel.text = tag.tag
        let (tagger, date) = tag.tagger.userIdAndDateString
        taggerLabel.text = tagger
        taggerDate.text = date
    }
}
