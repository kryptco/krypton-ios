//
//  LogCell.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/9/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

class SSHLogCell: UITableViewCell {
    
    @IBOutlet var signatureLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(log:SSHSignatureLog) {
        signatureLabel.text = log.displayName
        timeLabel.text = log.date.trailingTimeAgo()
    }
    
}

class GitCommitLogCell: UITableViewCell {
    
    @IBOutlet var topLine:UIView!
    @IBOutlet var bottomLine:UIView!
    @IBOutlet var commitHashLabel:UILabel!
    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(log:CommitSignatureLog, previousLog:CommitSignatureLog?, nextLog:CommitSignatureLog?) {
        
        // set short hash
        let hash = log.commitHash
        
        if hash.characters.count >= 7 {
            commitHashLabel.text = hash.substring(to: hash.index(hash.startIndex, offsetBy: 7))
        } else {
            commitHashLabel.text = hash
        }
        
        // message
        messageLabel.text = log.commit.messageString
        
        // set time
        timeLabel.text = log.date.trailingTimeAgo()
        
        topLine.alpha = 0.0
        bottomLine.alpha = 0.0
        
        // set the lines
        if  let parent = log.commit.parent,
            let previous = previousLog,
            previous.commitHash == parent
        {
            bottomLine.alpha = 1.0
        }
        
        if  let nextParent = nextLog?.commit.parent,
            log.commitHash == nextParent
        {
            topLine.alpha = 1.0
        }

    }
    
}

class GitTagLogCell: UITableViewCell {
    
    @IBOutlet var tagLabel:UILabel!
    @IBOutlet var commitHashLabel:UILabel!
    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(log:TagSignatureLog) {
        tagLabel.text = log.tag.tag
        commitHashLabel.text = log.tag.objectShortHash
        messageLabel.text = log.tag.messageString
        timeLabel.text = log.date.trailingTimeAgo()
    }
    
}

