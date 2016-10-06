//
//  MeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class MeController:KRBaseController, UITextFieldDelegate {
    @IBOutlet var qrImageView:UIImageView!
    @IBOutlet var tagTextField:UITextField!

    @IBOutlet var myQRButton:UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.redrawMe), name: NSNotification.Name(rawValue: "load_new_me"), object: nil)
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        myQRButton.setBorder(color: UIColor.clear, cornerRadius: 16, borderWidth: 0.0)
        
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
            showWarning(title: "Error", body: "Email address not found.")
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
    
    //MARK: Segue
    @IBAction func dismissQR(segue: UIStoryboardSegue) {
    }
    


}
