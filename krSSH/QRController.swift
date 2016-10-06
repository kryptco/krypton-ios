//
//  QRController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/29/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
class QRController:KRBaseController {
    
    @IBOutlet weak var qrImageView:UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let me = try KeyManager.sharedInstance().getMe()
            let json = try me.jsonString()
            
            let gen = RSUnifiedCodeGenerator()

            if let img = gen.generateCode(json, machineReadableCodeObjectType: AVMetadataObjectTypeQRCode)
            {
                let resized = RSAbstractCodeGenerator.resizeImage(img, targetSize: qrImageView.frame.size, contentMode: UIViewContentMode.scaleAspectFill)
                
                self.qrImageView.image = resized//.withRenderingMode(.alwaysTemplate)
            }

            
        } catch (let e) {
            log("error loading key pair: \(e)", .error)
            return
        }
    }
}
