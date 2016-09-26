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
import OctoKit

class MeController:UIViewController {
    @IBOutlet var qrImageView:UIImageView!
    @IBOutlet var tagLabel:UILabel!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
    
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.didFinishLoginToGitHub(note:)), name: NSNotification.Name(rawValue: "finish_github_login"), object: nil)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        redrawMe()
        Policy.currentViewController = self

    }
    
    
    dynamic func redrawMe() {
        do {
            
            let me = try KeyManager.sharedInstance().getMe()
            
            tagLabel.text = me.email
            
            //TODO: --> deal
            let json = try me.publicKey.fingerprint().toBase64()
            
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
   
    //MARK: Upload to GitHub
    
    @IBAction func uploadToGitHub() {
        
        let github = GitHub()
        
        guard github.accessToken == nil else {
            doGitHubUpload()
            return
        }
        
        guard let authURL = github.authConfig.authenticate() else {
            showWarning(title: "Error", body: "Cannot connect to GitHub.")
            log("error: github oauth url", .error)
            return
        }
        
        UIApplication.shared.openURL(authURL)
    }

    dynamic func didFinishLoginToGitHub(note:Notification) {
        guard let url = note.object as? URL else {
            log("no url in github login notification", .error)
            return
        }
        
        GitHub().getToken(url: url) { 
            self.doGitHubUpload()
        }
        
    }
    
    func doGitHubUpload() {
        guard let successVC = self.storyboard?.instantiateViewController(withIdentifier: "SuccessController") as? SuccessController
            else {
                log("no success controller storyboard", .error)
                return
        }
        
        successVC.resultImage = nil
        successVC.hudText = "Uploading Public Key to GitHub..."
        successVC.shouldSpin = true
        successVC.modalPresentationStyle = .overCurrentContext
        
        present(successVC, animated: true, completion: nil)
        
        let github = GitHub()
        do {
            let km = try KeyManager.sharedInstance()
            let email = try km.getMe().email
            let publicKeyWire = try km.keyPair.publicKey.wireFormat()
            let title = "kryptonite iOS <\(email)>"
            
            github.upload(title: title, publicKeyWire: publicKeyWire,
                          success: {
                            
                            dispatchMain {
                                successVC.spinner.stopAnimating()
                                successVC.resultImageView.image = ResultImage.check.image
                                successVC.titleLabel.text = "Success!"
                                dispatchAfter(delay: 2.0, task: {
                                    successVC.dismiss(animated: true, completion: nil)
                                    
                                })
                            }
                }, failure: { (error) in
                    dispatchMain {
                        successVC.spinner.stopAnimating()
                        successVC.resultImageView.image = ResultImage.x.image
                        successVC.titleLabel.text = "Error: \(error.message)"
                        dispatchAfter(delay: 3.0, task: {
                            successVC.dismiss(animated: true, completion: nil)
                            
                        })
                    }
                    
                    
            })
        }
        catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            self.showWarning(title: "Error loading keypair", body: "\(e)")
        }
    }
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        
        guard let km = try? KeyManager.sharedInstance(),
              let peer = try? km.getMe() ,
              let publicKeyWire = try? km.keyPair.publicKey.wireFormat()
        else {
            return
        }
        
        dispatchMain {
            self.present(self.textDialogue(for: peer, with: nil, and: publicKeyWire), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareEmailTapped() {
        guard let km = try? KeyManager.sharedInstance(),
            let peer = try? km.getMe() ,
            let publicKeyWire = try? km.keyPair.publicKey.wireFormat()
            else {
                return
        }

        
        dispatchMain {
            self.present(self.emailDialogue(for: peer, with: nil, and: publicKeyWire), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareCopyTapped() {
        guard let km = try? KeyManager.sharedInstance(),
            let peer = try? km.getMe() ,
            let publicKeyWire = try? km.keyPair.publicKey.wireFormat()
            else {
                return
        }

        
        copyDialogue(for: peer, and: publicKeyWire)
    }
    
    @IBAction func shareOtherTapped() {
        guard let km = try? KeyManager.sharedInstance(),
            let peer = try? km.getMe() ,
            let publicKeyWire = try? km.keyPair.publicKey.wireFormat()
        else {
            return
        }

        
        dispatchMain {
            self.present(self.otherDialogue(for: peer, and: publicKeyWire), animated: true, completion: nil)
        }
    }
}
