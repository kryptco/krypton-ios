//
//  PairedUploadController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class PairedUploadController:KRBaseController, GitHubDelegate {
    
    @IBOutlet weak var sessionLabel:UILabel!
    var session:Session?

    @IBOutlet weak var githubButton:UIButton!
    @IBOutlet weak var gitSSHView:UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.gitSSHView.alpha = 0.0

        if let session = session {
            sessionLabel.text = "\(session.pairing.name)"
        }
        
        self.askConfirmationIn(title: "Enable Push notifications?", text: "Push notifications are used to notify you when your private key is used. Push notifications signficiantly improve the app experience.", accept: "Enable", cancel: "Later")
        { (enable) in
            
            if enable {
                (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
            }
            UserDefaults.standard.set(true, forKey: "did_ask_push")
            UserDefaults.standard.synchronize()
        }

    }
    
    
    @IBAction func uploadToGitHub() {
        let github = GitHub()
        
        guard github.accessToken == nil else {
            self.doGithubUpload(token: github.accessToken!)
            return
        }
        
        guard let authURL = github.authConfig.authenticate() else {
            showWarning(title: "Error", body: "Cannot connect to GitHub.")
            log("error: github oauth url", .error)
            return
        }
        
        UIApplication.shared.openURL(authURL)
    }
    
    
    //MARK: GitHub Delegate
  
    func doGithubUpload(token: String?) {

        guard let successVC = self.storyboard?.instantiateViewController(withIdentifier: "SuccessController") as? SuccessController
            else {
                log("no success controller storyboard", .error)
                return
        }
        

        successVC.modalPresentationStyle = .overCurrentContext
        
        guard let accessToken = token else {
            successVC.hudText = "Invalid Credentials"
            successVC.resultImage = ResultImage.x.image
            present(successVC, animated: true, completion: nil)
            return
        }
    
        successVC.resultImage = nil
        successVC.shouldSpin = true
        successVC.hudText = "Uploading Public Key to GitHub..."
        present(successVC, animated: true, completion: nil)
        
        let github = GitHub()
        github.accessToken = accessToken
        
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
                                
                                self.githubButton.layer.borderColor = UIColor.clear.cgColor
                                self.githubButton.setTitle("Uploaded to Github!", for: UIControlState.normal)
                                self.githubButton.isEnabled = false
                                
                                dispatchAfter(delay: 2.0, task: {
                                    successVC.dismiss(animated: true, completion: nil)
                                    
                                    UIView.animate(withDuration: 1.0, animations: { 
                                        self.gitSSHView.alpha = 1.0
                                    })
                                    
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
