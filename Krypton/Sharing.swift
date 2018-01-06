//
//  Sharing.swift
//  Krypton
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import MessageUI


extension UIViewController: UINavigationControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate {
    
    
    // Sending
    func textDialogue(for me:String, authorizedKey:SSHAuthorizedFormat, with phone:String? = nil) -> UIViewController {
        
        let msgDialogue = MFMessageComposeViewController()
        
        if let phone = phone {
            msgDialogue.recipients = [phone]
        }
        msgDialogue.body = "This is my SSH public key. Store your SSH + PGP Keypair with \(Properties.appName) (\(Properties.appURL))."
        msgDialogue.messageComposeDelegate = self
        
        
        if let pkData = authorizedKey.data(using: String.Encoding.utf8) {
            msgDialogue.addAttachmentData(pkData, typeIdentifier: "public.plain-text", filename: "\(me).txt")
        }
        
        return msgDialogue
    }
    
    func emailDialogue(for authorizedKey:SSHAuthorizedFormat, with email:String? = nil) -> UIViewController {
        
        guard MFMailComposeViewController.canSendMail() else {
            return unsupportedDialogue()
        }
        
        let mailDialogue = MFMailComposeViewController()
        if let email = email {
            mailDialogue.setToRecipients([email])
        }
    
        mailDialogue.setSubject("My SSH Public Key")
        mailDialogue.mailComposeDelegate = self
        
        mailDialogue.setMessageBody("My SSH public key is:\n\n\(authorizedKey)\n\n\n--\nSent via \(Properties.appName) (\(Properties.appURL))", isHTML: false)

        Resources.makeAppearences()

        return mailDialogue
    }
    
    func copyDialogue(for me:String, authorizedKey:SSHAuthorizedFormat) {
        UIPasteboard.general.string = authorizedKey.byAdding(comment: me)
        performSegue(withIdentifier: "showSuccess", sender: nil)
    }
    
    func otherDialogueNative(for me:String, authorizedKey:SSHAuthorizedFormat) -> UIActivityViewController {
        let textItem = authorizedKey.byAdding(comment: me)
        
        let otherDialogue = UIActivityViewController(activityItems: [textItem
            ], applicationActivities: nil)
        
        
        return otherDialogue

    }
    
    func otherDialogue(for me:String, authorizedKey:SSHAuthorizedFormat) -> UIViewController {
        
        let title = "Share My Public Key"
        let message = "Send your public key so peers can give you access to servers and code repositories. Don't worry, your private key never leaves this device."
        
            let alertController:UIAlertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        
        alertController.addAction(UIAlertAction(title: "Mail", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.emailDialogue(for: authorizedKey), animated: true, completion: nil)
        }))
        
        alertController.addAction(UIAlertAction(title: "SMS", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.textDialogue(for: me, authorizedKey: authorizedKey), animated: true, completion: nil)
        }))

        
        alertController.addAction(UIAlertAction(title: "Other", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            
            self.present(self.otherDialogueNative(for: me, authorizedKey: authorizedKey), animated: true, completion: nil)
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

