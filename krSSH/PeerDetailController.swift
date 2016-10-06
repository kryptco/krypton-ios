//
//  PeerDetailController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit

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
        
        self.askConfirmationIn(title: "Delete", text: "Are you sure you want to delete \(peer?.email ?? "")'s public key?", accept: "Delete", cancel: "Cancel")
        { (yes) in
            guard yes else {
                return
            }
            
            guard let peer = self.peer else {
                return
            }
            
            PeerManager.shared.remove(peer: peer)
            dispatchMain {
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    
    dynamic func drawPeer() {
        tagLabel.text = peer?.email
        dateLabel.text = "Added " + (peer?.dateAdded.toShortTimeString() ?? "?")

        qrImageView.image = IGSimpleIdenticon.from(peer?.publicKey.toBase64() ?? "", size: CGSize(width: 80, height: 80))



    }
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.textDialogue(for: peer), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareEmailTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.emailDialogue(for: peer), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareCopyTapped() {
        guard let peer = peer else {
            return
        }
        
        copyDialogue(for: peer)
    }
    
    @IBAction func shareOtherTapped() {
        guard let peer = peer else {
            return
        }
        
        dispatchMain {
            self.present(self.otherDialogue(for: peer), animated: true, completion: nil)
        }
    }
    
}
