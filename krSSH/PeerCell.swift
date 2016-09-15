//
//  PeerCell.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class PeerCell: UITableViewCell {
    
    @IBOutlet var tagLabel:UILabel!
    @IBOutlet var dateLabel:UILabel!

    @IBOutlet var identiconView:UIImageView!

    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func set(peer:Peer) {
        identiconView.image = IGSimpleIdenticon.from(peer.publicKey, size: CGSize(width: 80, height: 80))
        tagLabel.text = peer.email
        dateLabel.text = "Added \(peer.dateAdded.toShortTimeString())"

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
