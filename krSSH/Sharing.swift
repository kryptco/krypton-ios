//
//  Sharing.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import MessageUI


extension UIViewController: UINavigationControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate {
    
    // Requesting
    func smsRequest(for phone:String) -> UIViewController {
        
        let msgDialogue = MFMessageComposeViewController()
        msgDialogue.recipients = [phone]
        msgDialogue.body = "Please send me your SSH public key with kryptonite! \(Link.publicKeyRequest())"
        msgDialogue.messageComposeDelegate = self
        
        
        return msgDialogue
    }
    
    func emailRequest(for email:String) -> UIViewController {
        let mailDialogue = MFMailComposeViewController()
        mailDialogue.setToRecipients([email])
        
        mailDialogue.setSubject("Requesting your SSH public key")
        mailDialogue.setMessageBody("Please send me your SSH public key with kryptonite! \(Link.publicKeyRequest())", isHTML: false)
        mailDialogue.mailComposeDelegate = self
                
        return mailDialogue
    }

    
    // Sending
    func textDialogue(for peer:Peer, with phone:String? = nil) -> UIViewController {
        
        let msgDialogue = MFMessageComposeViewController()
        
        if let phone = phone {
            msgDialogue.recipients = [phone]
        }
        msgDialogue.body = "\(peer.publicKey.toAuthorized()) \(peer.email)"
        msgDialogue.messageComposeDelegate = self
        
        
        let authorizedKey = peer.publicKey.toAuthorized()
        
        if let pkData = "\(authorizedKey) \(peer.email)".data(using: String.Encoding.utf8) {
            msgDialogue.addAttachmentData(pkData, typeIdentifier: "public.plain-text", filename: "publickey.kr")
        }
    

        msgDialogue.body = "Import \(peer.email)'s public key with kryptonite!"

        
        return msgDialogue
    }
    
    func emailDialogue(for peer:Peer, with email:String? = nil) -> UIViewController {
        let mailDialogue = MFMailComposeViewController()
        if let email = email {
            mailDialogue.setToRecipients([email])
        }
    
        mailDialogue.setSubject("My SSH Public Key")
        mailDialogue.mailComposeDelegate = self
        
        let authorizedKey = peer.publicKey.toAuthorized()
        
        if let pkData = "\(authorizedKey) \(peer.email)".data(using: String.Encoding.utf8) {
            mailDialogue.addAttachmentData(pkData, mimeType: "text/plain", fileName: "publickey.kr")
        }
        
        mailDialogue.setMessageBody("<a href=\"\(Link.publicKeyImport())\"> Import \(peer.email)'s public key with kryptonite by tapping here</a> or download the public key attached below. ", isHTML: true)

        

        Resources.makeAppearences()

        return mailDialogue
    }
    
    func copyDialogue(for peer:Peer) {
        UIPasteboard.general.string = "\(peer.publicKey.toAuthorized()) \(peer.email)"
        performSegue(withIdentifier: "showSuccess", sender: nil)
    }
    
    func otherDialogueNative(for peer:Peer) -> UIViewController {
        let textItem = "\(peer.publicKey.toAuthorized()) \(peer.email)"
        
        let otherDialogue = UIActivityViewController(activityItems: [textItem
            ], applicationActivities: nil)
        
        
        return otherDialogue

    }
    
    func otherDialogue(for peer:Peer) -> UIViewController {
        
        
        let alertController:UIAlertController = UIAlertController(title: "Share my Public Key", message: "The private key never leaves your device.", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        
        alertController.addAction(UIAlertAction(title: "Mail", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.emailDialogue(for: peer), animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: "SMS", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.textDialogue(for: peer), animated: true, completion: nil)
        }))

        
        alertController.addAction(UIAlertAction(title: "Other", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.otherDialogueNative(for: peer), animated: true, completion: nil)
        }))
        
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action:UIAlertAction) -> Void in
            
            
        }))
        

        return alertController
    }
    
    func savePublicKeyToFile(key: String) -> URL? {
        let file = "publickey.kr"
        
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first  else {
            
            return nil
        }
        
        let path = dir.appendingPathComponent(file)
        
        //writing
        do {
            try key.write(to: path, atomically: false, encoding: String.Encoding.utf8)
            return path
        }
        catch {/* error handling here */}
        
        return nil

    }
    
    //MARK: Delegates
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        Resources.makeAppearences()

        controller.dismiss(animated: true, completion: nil)
    }
    
    
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        Resources.makeAppearences()
        controller.dismiss(animated: true, completion: nil)
    }
}

