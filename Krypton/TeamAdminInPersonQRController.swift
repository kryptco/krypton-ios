//
//  TeamAdminInPersonQRController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation


class TeamAdminInPersonQRController:KRBaseController {
    
    @IBOutlet weak var createButton:UIButton!
    @IBOutlet weak var createView:UIView!
    @IBOutlet weak var qrView:UIImageView!

    var identity:TeamIdentity!
    
    var newMemberPayload:NewMemberQRPayload?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        createButton.layer.shadowOpacity = 0.175
        createButton.layer.shadowRadius = 3
        createButton.layer.masksToBounds = false
        
        createView.layer.shadowColor = UIColor.black.cgColor
        createView.layer.shadowOffset = CGSize(width: 0, height: 0)
        createView.layer.shadowOpacity = 0.175
        createView.layer.shadowRadius = 3
        createView.layer.masksToBounds = false
        
        do {
            let teamName = try identity.dataManager.withTransaction { try $0.fetchTeam() }.name
            let qrPayload = try AdminQRPayload(lastBlockHash: identity.checkpoint,
                                               teamPublicKey: identity.initialTeamPublicKey,
                                               teamName: teamName).jsonString()
            let generator = RSUnifiedCodeGenerator()
            generator.strokeColor = UIColor.appBlack
            
            let screenWidth = UIScreen.main.bounds.width*UIScreen.main.scale
            
            if let image = generator.generateCode(qrPayload, inputCorrectionLevel: .Low, machineReadableCodeObjectType: AVMetadataObject.ObjectType.qr.rawValue) {
                qrView.image = RSAbstractCodeGenerator.resizeImage(image, targetSize: CGSize(width: screenWidth, height: screenWidth), contentMode: UIViewContentMode.center)
            }
        } catch {
            self.showWarning(title: "Error", body: "Could not generate QR code. \(error)")
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dispatchAfter(delay: 4.0) {
            self.createButton.pulse(scale: 1.2, duration: 0.5)
        }
    }
    @IBAction func cancelTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func nextTapped() {
        if let payload = newMemberPayload {
            self.performSegue(withIdentifier: "showEmailConfirmation", sender: payload)
        } else {
            self.performSegue(withIdentifier: "showScanController", sender: nil)
        }
    }
    
    @IBAction func backToDisplayQRCode(segue: UIStoryboardSegue) {
    }
    
    @IBAction func unwindAndDismiss(segue: UIStoryboardSegue) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? TeamAdminInPersonScanController {
            controller.identity = identity
        }
        else    if let confirmController = segue.destination as? TeamConfirmInPersonController,
                let payload = sender as? NewMemberQRPayload
        {
            confirmController.identity = self.identity
            confirmController.payload = payload
        }
    }
    
    
}
