//
//  SessionCell.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class SessionCell: UITableViewCell {
    
    @IBOutlet var deviceNameLabel:UILabel!
    @IBOutlet var lastAccessLabel:UILabel!
    @IBOutlet var barView:LogGraph!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(session:Session) {
        deviceNameLabel.text = session.pairing.name
        lastAccessLabel.text = "Active as of " + (session.lastAccessed?.timeAgo() ?? session.created.timeAgo())
        
        let logDates = LogManager.shared.all.filter({$0.session == session.id}).map({ $0.date })
        barView.fillColor = UIColor.colorFromString(string: session.id).withAlphaComponent(0.3)
        barView.set(values: logDates)
    }

}
