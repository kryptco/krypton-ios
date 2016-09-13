//
//  LogCell.swift
//  krSSH
//
//  Created by Alex Grinman on 9/9/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

class LogCell: UITableViewCell {
    
    @IBOutlet var signatureLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(log:SignatureLog) {
        if let hexSig = log.digest.fromBase64()?.hexPretty {
            signatureLabel.text = hexSig
        } else {
            signatureLabel.text = log.digest
        }
        timeLabel.text = log.date.toLongTimeString()
    }
    
}
