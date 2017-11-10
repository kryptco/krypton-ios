//
//  CommitApproveController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class GitCommitRequestController:UIViewController {
    
    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var authorLabel:UILabel!
    @IBOutlet weak var authorDateLabel:UILabel!
    
    @IBOutlet weak var committerLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func set(commit:CommitInfo) {
        messageLabel.text = commit.messageString
        let (author, date) = commit.author.userIdAndDateString
        let (committer, committerDate) = commit.committer.userIdAndDateString
        
        if author == committer {
            authorLabel.text = author
            authorDateLabel.text = date
            committerLabel.text = ""
        } else {
            authorLabel.text = "A: " + author
            committerLabel.text = "C: " + committer
            authorDateLabel.text = committerDate
        }
    }
    
}
