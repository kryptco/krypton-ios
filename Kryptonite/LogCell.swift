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
        signatureLabel.text = log.displayName
        timeLabel.text = log.date.timeAgo()
    }
    
}
