//
//  PeerDetailController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation

class PeerDetailController: UIViewController {

    @IBOutlet var qrImageView:UIImageView!

    @IBOutlet var tagLabel:UILabel!
    @IBOutlet var dateLabel:UILabel!

    
    var peer:Peer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = peer?.email ?? "Detail"
        drawPeer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func delete() {
        
    }
    
    
    dynamic func drawPeer() {
        tagLabel.text = peer?.email
        dateLabel.text = peer?.dateAdded.toShortTimeString()

        if  let p = peer,
            let json = try? p.jsonString(),
            let img = RSUnifiedCodeGenerator().generateCode(json, machineReadableCodeObjectType: AVMetadataObjectTypeQRCode)
        {
            
            let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: qrImageView.frame.size, contentMode: UIViewContentMode.scaleAspectFill)
            
            self.qrImageView.image = resized//.withRenderingMode(.alwaysTemplate)
        } else {
            log("problem creating qr code for peer", .error)
        }

    }
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        guard let peer = peer else {
            return
        }
        
        present(Sharing.textDialogue(for: peer, with: nil), animated: true, completion: nil)
    }
    
    @IBAction func shareEmailTapped() {
        guard let peer = peer else {
            return
        }
        
        present(Sharing.emailDialogue(for: peer, with: nil), animated: true, completion: nil)
    }
    
    @IBAction func shareCopyTapped() {
        guard let peer = peer else {
            return
        }
        
        present(Sharing.copyDialogue(for: peer), animated: true, completion: nil)
    }
    
    @IBAction func shareOtherTapped() {
        guard let peer = peer else {
            return
        }
        
        present(Sharing.otherDialogue(for: peer), animated: true, completion: nil)
    }
    
}
