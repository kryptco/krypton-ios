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
    
    
    // Sending
    func textDialogue(for peer:Peer, with phone:String? = nil) -> UIViewController {
        
        let msgDialogue = MFMessageComposeViewController()
        
        if let phone = phone {
            msgDialogue.recipients = [phone]
        }
        msgDialogue.body = "This is my SSH public key. Store your SSH Keypair with Kryptonite \(Properties.appURL))."
        msgDialogue.messageComposeDelegate = self
        

        let authorizedKey = peer.publicKey.toAuthorized()
        
        if let pkData = "\(authorizedKey) \(peer.email)".data(using: String.Encoding.utf8) {
            msgDialogue.addAttachmentData(pkData, typeIdentifier: "public.plain-text", filename: "publickey.kr")
        }
        
        return msgDialogue
    }
    
    func emailDialogue(for peer:Peer, with email:String? = nil) -> UIViewController {
        
        guard MFMailComposeViewController.canSendMail() else {
            return unsupportedDialogue()
        }
        
        let mailDialogue = MFMailComposeViewController()
        if let email = email {
            mailDialogue.setToRecipients([email])
        }
    
        mailDialogue.setSubject("My SSH Public Key")
        mailDialogue.mailComposeDelegate = self
        
        let authorizedKey = peer.publicKey.toAuthorized()
        
        mailDialogue.setMessageBody("My SSH public key is:\n\n\(authorizedKey)\n\n--\n Sent via Kryptonite (\(Properties.appURL))", isHTML: true)

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
    
    func otherDialogue(for peer:Peer, me:Bool = false) -> UIViewController {
        
        var title:String
        var message:String
        
        if me {
            title = "Share My Public Key"
            message = "Send your public key so peers can give you access to servers and code repositories. Don't worry, your private key never leaves this device."
        } else {
            title = "Share \(peer.email)'s Public Key"
            message = "Send \(peer.email)'s public key so peers can give them access to servers and code repositories."
        }
        
        let alertController:UIAlertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        
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
    
    func unsupportedDialogue() -> UIViewController {
        let alertController:UIAlertController = UIAlertController(title: "Unsupported sharing action.", message: "You are missing the right app to share a public key this way.", preferredStyle: UIAlertControllerStyle.alert)
        
        
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
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

