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
    @IBOutlet var shareButton:UIButton!

    @IBOutlet var identiconImageView:UIImageView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        redrawMe()
    }
    
    
    
    dynamic func redrawMe() {
        //   qrImageView.setBorder(color: UIColor.black.withAlphaComponent(0.5), cornerRadius: qrImageView.frame.size.width/2, borderWidth: 2.0)
        //  identiconImageView.setBorder(color: UIColor.black.withAlphaComponent(0.5), cornerRadius: identiconImageView.frame.size.width/2, borderWidth: 2.0)
        do {
            let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
            // let fp = try publicKey.fingerprint().hexPretty
            //keyLabel.text = fp.substring(to: fp.index(fp.startIndex, offsetBy: 32))
            
            tagLabel.text = try KeyManager.sharedInstance().getMe().email
            
            if let ident = IGSimpleIdenticon.from(publicKey, size: CGSize(width: identiconImageView.frame.size.width, height: identiconImageView.frame.size.height))
            {
                identiconImageView.image = ident
                
            }
            
            
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
   
}
