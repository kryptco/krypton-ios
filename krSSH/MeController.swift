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
    @IBOutlet var identiconImageView:UIImageView!
    @IBOutlet var qrImageView:UIImageView!
    @IBOutlet var tagLabel:UILabel!
    @IBOutlet var keyLabel:UILabel!
    @IBOutlet var shareButton:UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        qrImageView.setBorder(color: UIColor.clear, cornerRadius: 12.0, borderWidth: 0.0)
        do {
            let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
            let fp = try publicKey.fingerprint().hexPretty
            keyLabel.text = fp.substring(to: fp.index(fp.startIndex, offsetBy: 32))

            tagLabel.text = try KeyManager.sharedInstance().getMe().email
            
            identiconImageView.image =  IGSimpleIdenticon.from(publicKey, size: CGSize(width: identiconImageView.frame.size.width, height: identiconImageView.frame.size.height))
            
            let json = try KeyManager.sharedInstance().getMe().jsonString()
            
            if let img = RSUnifiedCodeGenerator.shared.generateCode(json, machineReadableCodeObjectType: AVMetadataObjectTypeQRCode) {
                
                let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: qrImageView.frame.size, contentMode: UIViewContentMode.scaleAspectFill)
                
                self.qrImageView.image = resized
            }
            
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error loading keypair", body: "\(e)")
        }
    }
    /*
 
  

 */
}
