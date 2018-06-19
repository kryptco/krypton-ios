//
//  SessionCell.swift
//  Krypton
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
            lastAccessLabel.text = ""
        }
        
    }
}

class BrowserSessionCell: UITableViewCell {
    
    @IBOutlet var deviceNameLabel:UILabel!
    @IBOutlet var lastAccessLabel:UILabel!
    @IBOutlet var browserLogo:UIImageView!
    @IBOutlet var logo:UIImageView!
    @IBOutlet var commandView:UIView!
    
    @IBOutlet weak var action:UILabel!
    @IBOutlet weak var suffix:UILabel!
    @IBOutlet weak var display:UILabel!
    
    @IBOutlet weak var textAdjust:NSLayoutConstraint!



    override func awakeFromNib() {
        super.awakeFromNib()
        commandView.setBoxShadow()
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }

    
    func set(session:Session) {
        
        deviceNameLabel.text = session.pairing.displayName.uppercased()
        browserLogo.image = session.pairing.browser?.kind.logo
        
        // set the last log
        guard let lastLog:U2FLog = LogManager.shared.fetchLatest(for: session.id) else {
            action.text = "No"
            suffix.text = "Activity"
            display.text = ""
            lastAccessLabel.text = ""
            logo.image = #imageLiteral(resourceName: "default")
            textAdjust.constant = 10
            
            return
        }
        
        textAdjust.constant = 0
        
        lastAccessLabel.text = lastLog.date.timeAgo()

        if lastLog.isRegister {
            action.text = "Registered"
            suffix.text = "with"
        } else {
            action.text = "Logged"
            suffix.text = "in"
        }
        
        let known = KnownU2FApplication(for: lastLog.appID)
        
        logo.image = known?.logo ?? #imageLiteral(resourceName: "default")
        display.text = known?.displayName ?? lastLog.appID.simpleDisplay
    }
}

