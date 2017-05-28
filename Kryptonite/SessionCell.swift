//
//  SessionCell.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit

class SessionCell: UITableViewCell {
    
    @IBOutlet var deviceNameLabel:UILabel!
    @IBOutlet var lastAccessLabel:UILabel!
    @IBOutlet var commandLabel:UILabel!
    @IBOutlet var commandView:UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        commandView.layer.shadowColor = UIColor.black.cgColor
        commandView.layer.shadowOffset = CGSize(width: 0, height: 0)
        commandView.layer.shadowOpacity = 0.175
        commandView.layer.shadowRadius = 3
        commandView.layer.masksToBounds = false

    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
    }
    
    func set(session:Session) {

        deviceNameLabel.text = session.pairing.displayName.uppercased()
        
        // find latest log
        var latestLogs:[LogStatement] = []
        
        if let sshLog:SSHSignatureLog = LogManager.shared.fetchLatest(for: session.id) {
            latestLogs.append(sshLog)
        }
        
        if let commitLog:CommitSignatureLog = LogManager.shared.fetchLatest(for: session.id) {
           latestLogs.append(commitLog)
        }
        
        if let tagLog:TagSignatureLog = LogManager.shared.fetchLatest(for: session.id) {
            latestLogs.append(tagLog)
        }
        
        
        // set the last log
        if let lastLog = LogManager.shared.fetchCompleteLatest(for: session.id) {
            commandLabel.text = "\(lastLog.displayName)"
            lastAccessLabel.text = lastLog.date.timeAgo()
        } else {
            commandLabel.text = "No activity"
            lastAccessLabel.text = "--"
        }
        
    }

}
