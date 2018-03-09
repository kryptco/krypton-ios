//
//  TeamMemberInPersonQRController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/17/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import AVFoundation

class TeamMemberInPersonQRController:KRBaseController {
    
    @IBOutlet weak var createView:UIView!
    @IBOutlet weak var qrView:UIImageView!
    @IBOutlet weak var arcView:UIView!

    var payload:AdminQRPayload!
    var email:String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        createView.layer.shadowColor = UIColor.black.cgColor
        createView.layer.shadowOffset = CGSize(width: 0, height: 0)
        createView.layer.shadowOpacity = 0.175
        createView.layer.shadowRadius = 3
        createView.layer.masksToBounds = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        do {
            let teamIdentity:TeamIdentity = try TeamIdentity.newMember(email: email,
                                                  checkpoint: payload.lastBlockHash,
                                                  initialTeamPublicKey: payload.teamPublicKey)
            
            
            let qrPayload = try NewMemberQRPayload(publicKey: teamIdentity.publicKey, email: email).jsonString()
            let generator = RSUnifiedCodeGenerator()
            generator.strokeColor = UIColor.appBlack
            
            let screenWidth = UIScreen.main.bounds.width*UIScreen.main.scale
            
            if let image = generator.generateCode(qrPayload, inputCorrectionLevel: .Low, machineReadableCodeObjectType: AVMetadataObject.ObjectType.qr.rawValue) {
                qrView.image = RSAbstractCodeGenerator.resizeImage(image, targetSize: CGSize(width: screenWidth, height: screenWidth), contentMode: UIViewContentMode.center)
            }

            dispatchAsync {
                self.waitForAdmin(teamIdentity: teamIdentity)
            }

        } catch {
            self.showWarning(title: "Error", body: "Could not generate QR code. \(error)")
            return
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arcView.spinningArc(lineWidth: 2.0, ratio: 0.5)
    }
    
    var viewDisappeared:Bool = false
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewDisappeared = true
    }

    func waitForAdmin(teamIdentity:TeamIdentity) {
        sleep(2)
        
        if viewDisappeared {
            return
        }
        
        let service = TeamService.temporary(for: teamIdentity)
        
        dispatchMain { UIApplication.shared.isNetworkActivityIndicatorVisible = true }
        
        do {
            let result = try service.getVerifiedTeamUpdatesSync()
            switch result {
            case .error(let e):
                log("didn't successfully load team blocks: \(e)", .warning)
                
                // try again
                self.waitForAdmin(teamIdentity: teamIdentity)
                
            case .result(let service):
                // got team updates
                dispatchMain {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                
                    let teamLoadController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamLoadController") as! TeamLoadController
                    
                    teamLoadController.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                    teamLoadController.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
                    
                    teamLoadController.joinType = .directInvite(service.teamIdentity)
                    
                    self.present(teamLoadController, animated: true, completion: nil)
                }
            }
        } catch {
            self.showWarning(title: "Error Fetching Team", body: "\(error)")
        }

    }
    
    
}
