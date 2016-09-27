//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit
import OctoKit

class MeController:KRBaseController, UITextFieldDelegate {
    @IBOutlet var qrImageView:UIImageView!
    @IBOutlet var tagTextField:UITextField!

    
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
            tagTextField.text = me.email
            
            qrImageView.image = IGSimpleIdenticon.from(me.publicKey.toBase64(), size: CGSize(width: 80, height: 80))
            
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
    
    //MARK: Sharing
    
    @IBAction func shareTextTapped() {
        
        guard let me = try? KeyManager.sharedInstance().getMe()
        else {
            return
        }
        
        dispatchMain {
            self.present(self.textDialogue(for: me), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareEmailTapped() {
        guard let me = try? KeyManager.sharedInstance().getMe()
        else {
            return
        }
        
        dispatchMain {
            self.present(self.emailDialogue(for: me), animated: true, completion: nil)
        }
    }
    
    @IBAction func shareCopyTapped() {
        guard let me = try? KeyManager.sharedInstance().getMe()
        else {
            return
        }
        
        copyDialogue(for: me)
    }
    
    @IBAction func shareOtherTapped() {
        guard let me = try? KeyManager.sharedInstance().getMe()
        else {
            return
        }

        
        dispatchMain {
            self.present(self.otherDialogue(for: me), animated: true, completion: nil)
        }
    }
    
    
    //MARK: TextField Delegate -> Editing Email
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
//        let text = textField.text ?? ""
//        let txtAfterUpdate = (text as NSString).replacingCharacters(in: range, with: string)
        
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let email = textField.text else {
            return false
        }
        
        if email.isEmpty {
            tagTextField.text = (try? KeyManager.sharedInstance().getMe().email) ?? ""
        } else {
           try? KeyManager.sharedInstance().setMe(email: email)
        }
        
        textField.resignFirstResponder()
        return true
    }

}
