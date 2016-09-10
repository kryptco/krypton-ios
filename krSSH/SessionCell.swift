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
    @IBOutlet var colorView:UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(session:Session) {
        colorView.backgroundColor = UIColor.colorFromString(string: session.id).withAlphaComponent(0.7)
        deviceNameLabel.text = session.pairing.name
        lastAccessLabel.text = "used \(session.created.timeAgo())"
    }

}
