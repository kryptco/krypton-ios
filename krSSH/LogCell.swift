//
//  LogCell.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/9/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

class LogCell: UITableViewCell {
    
    @IBOutlet var signatureLabel:UILabel!
    @IBOutlet var timeLabel:UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(log:SignatureLog) {
        if let command = log.command {
            signatureLabel.text = "$ \(command)"
        } else {
            if  let sig = try? log.digest.fromBase64()
            {
                signatureLabel.text = sig.hexPretty
            } else {
                signatureLabel.text = log.digest
            }
        }
        timeLabel.text = log.date.timeAgo()
    }
    
}
