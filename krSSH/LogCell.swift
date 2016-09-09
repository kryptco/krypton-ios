//
//  LogCell.swift
//  krSSH
//
//  Created by Alex Grinman on 9/9/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

class LogCell: UITableViewCell {
    
    @IBOutlet var colorView:UIView!
    @IBOutlet var signatureLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func set(log:SignatureLog) {
        colorView.backgroundColor = UIColor.colorFromString(string: log.session).withAlphaComponent(0.7)
        signatureLabel.text = log.signature.uppercased()
        timeLabel.text = log.date.toLongTimeString()
    }
    
}
