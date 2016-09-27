//
//  PeerDetailController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class PeerDetailController: KRBaseController {

    @IBOutlet var qrImageView:UIImageView!

    @IBOutlet var tagLabel:UILabel!
    @IBOutlet var dateLabel:UILabel!

    
    var peer:Peer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = peer?.email ?? "Detail"
        drawPeer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func delete() {
        
    }
    
    
    dynamic func drawPeer() {
        tagLabel.text = peer?.email
        dateLabel.text = "Added " + (peer?.dateAdded.toShortTimeString() ?? "?")

        qrImageView.image = IGSimpleIdenticon.from(peer?.publicKey ?? "", size: CGSize(width: 80, height: 80))



    }
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.textDialogue(for: peer, with: nil, and: peer.publicKey), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareEmailTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.emailDialogue(for: peer, with: nil, and: peer.publicKey), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareCopyTapped() {
        guard let peer = peer else {
            return
        }
        
        copyDialogue(for: peer, and: peer.publicKey)
    }
    
    @IBAction func shareOtherTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.otherDialogue(for: peer, and: peer.publicKey), animated: true, completion: nil)
        }
    }
    
}
