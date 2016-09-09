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
        if let fp = log.signature.fromBase64()?.hexPretty, fp.characters.count >= 16 {
            signatureLabel.text = fp.substring(to: fp.index(fp.startIndex, offsetBy: 16))
        } else {
            signatureLabel.text = ""
        }
        timeLabel.text = log.date.toLongTimeString()
    }
    
}
