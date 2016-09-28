//
//  PairedUploadController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class PairedUploadController:KRBaseController {
    
    @IBOutlet weak var sessionLabel:UILabel!
    var session:Session?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        NotificationCenter.default.addObserver(self, selector: #selector(MeController.didFinishLoginToGitHub(note:)), name: NSNotification.Name(rawValue: "finish_github_login"), object: nil)

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = session {
            sessionLabel.text = "\(session.pairing.name)"
        }
        
        self.askConfirmationIn(title: "Enable Push notifications?", text: "Push notifications are used to notify you when your private key is used. Push notifications signficiantly improve the app experience.", accept: "Enable", cancel: "Later")
        { (enable) in
            
            if enable {
                (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
            }
        }

    }
    
    
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
            let authorizedKey = try km.keyPair.publicKey.authorizedFormat()
            let title = "kryptonite iOS <\(email)>"
            
            github.upload(title: title, publicKeyWire: authorizedKey,
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

    
    @IBAction func shareManually() {
        guard let me = try? KeyManager.sharedInstance().getMe()
            else {
                return
        }
        
        self.present(self.otherDialogue(for: me), animated: true, completion: nil)

    }

}
