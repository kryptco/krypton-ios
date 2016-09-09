//
//  SessionCell.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class SessionCell: UITableViewCell {
    
    @IBOutlet var deviceIcon:UILabel!
    @IBOutlet var dateIcon:UILabel!
    @IBOutlet var loginIcon:UILabel!
    
    @IBOutlet var deviceNameLabel:UILabel!
    @IBOutlet var lastAccessLabel:UILabel!
    @IBOutlet var loginCountLabel:UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
//        deviceIcon.FAIcon = FAType.FADesktop
//        dateIcon.FAIcon = FAType.FAClockO
//        loginIcon.FAIcon = FAType.FASignIn
    }
    
    func set(session:Session) {
        deviceNameLabel.text = session.pairing.name
        lastAccessLabel.text = session.created.toShortTimeString()
    }

}
