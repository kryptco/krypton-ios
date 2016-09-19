//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class MeController:UIViewController {
    @IBOutlet var qrImageView:UIImageView!
    @IBOutlet var tagLabel:UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        redrawMe()
    }
    
    
    
    dynamic func redrawMe() {
        do {
            tagLabel.text = try KeyManager.sharedInstance().getMe().email
            
            let json = try KeyManager.sharedInstance().getMe().jsonString()
            
            let gen = RSUnifiedCodeGenerator()
            gen.strokeColor = UIColor.red
            gen.fillColor = UIColor.clear
            
            if let img = gen.generateCode(json, machineReadableCodeObjectType: AVMetadataObjectTypeQRCode) {
                
                
                let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: qrImageView.frame.size, contentMode: UIViewContentMode.scaleAspectFill)
                
                self.qrImageView.image = resized//.withRenderingMode(.alwaysTemplate)
            }
            
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error loading keypair", body: "\(e)")
        }
    }
   
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        guard let peer = try? KeyManager.sharedInstance().getMe() else {
            return
        }
        
        dispatchMain {
            self.present(self.textDialogue(for: peer, with: nil), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareEmailTapped() {
        guard let peer = try? KeyManager.sharedInstance().getMe() else {
            return
        }
        
        dispatchMain {
            self.present(self.emailDialogue(for: peer, with: nil), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareCopyTapped() {
        guard let peer = try? KeyManager.sharedInstance().getMe() else {
            return
        }
        
        copyDialogue(for: peer)
    }
    
    @IBAction func shareOtherTapped() {
        guard let peer = try? KeyManager.sharedInstance().getMe() else {
            return
        }
        dispatchMain {
            self.present(self.otherDialogue(for: peer), animated: true, completion: nil)
        }
    }
}
