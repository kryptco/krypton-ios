//
//  PeerCell.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class PeerCell: UITableViewCell {
    @IBOutlet var keyIcon:UILabel!
    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet var tagIcon:UILabel!
    @IBOutlet var tagLabel:UILabel!

    @IBOutlet var identiconView:UIImageView!

    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        keyIcon.FAIcon = FAType.FAKey
        tagIcon.FAIcon = FAType.FATag
        
        identiconView.setBorder(color: UIColor.clear, cornerRadius: 20, borderWidth: 1.0)
    }
    
    func set(peer:Peer) {
        identiconView.image = IGSimpleIdenticon.from(peer.publicKey, size: CGSize(width: 40, height: 40))
        keyLabel.text = try? peer.publicKey.fingerprint().hexPretty
        tagLabel.text = peer.email
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
