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
    @IBOutlet var commandLabel:UILabel!
    @IBOutlet var colorView:UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(session:Session) {
        deviceNameLabel.text = session.pairing.name.uppercased()
        lastAccessLabel.text = (session.lastAccessed?.timeAgo() ?? session.created.timeAgo())
        
        if let command = LogManager.shared.all.filter({$0.session == session.id}).sorted(by: {$0.date > $1.date}).first?.command {
            let user = session.pairing.name.getUserOrNil() ?? ""
            commandLabel.text = "\(user) $ \(command)"
        } else {
            commandLabel.text = " $ "
        }
        
        colorView.backgroundColor = UIColor.colorFromString(string: session.id).withAlphaComponent(0.3)
    }

}
