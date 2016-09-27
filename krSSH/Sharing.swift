//
//  Sharing.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import MessageUI


extension UIViewController: UINavigationControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate {
    
    // Requesting
    func smsRequest(for phone:String) -> UIViewController {
        
        UINavigationBar.appearance().tintColor = UIColor.app
        UIBarButtonItem.appearance().tintColor = UIColor.app
        
        UINavigationBar.appearance().titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.app,
            NSFontAttributeName: UIFont(name: "Avenir Next", size: 17)!
        ]
        
        let msgDialogue = MFMessageComposeViewController()
        msgDialogue.recipients = [phone]
        msgDialogue.body = "Please send me your SSH public key with kryptonite! \(Link.publicKeyRequest())"
        msgDialogue.messageComposeDelegate = self
        
        Resources.makeAppearences()
        
        return msgDialogue
    }
    
    func emailRequest(for email:String) -> UIViewController {
        let mailDialogue = MFMailComposeViewController()
        mailDialogue.setToRecipients([email])
        
        mailDialogue.setSubject("Requesting your SSH public key")
        mailDialogue.setMessageBody("Please send me your SSH public key with kryptonite! \(Link.publicKeyRequest())", isHTML: false)
        mailDialogue.mailComposeDelegate = self
        
        Resources.makeAppearences()
        
        return mailDialogue
    }

    
    // Sending
    func textDialogue(for peer:Peer, with phone:String? = nil) -> UIViewController {
        
        UINavigationBar.appearance().tintColor = UIColor.app
        UIBarButtonItem.appearance().tintColor = UIColor.app

        UINavigationBar.appearance().titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.app,
            NSFontAttributeName: UIFont(name: "Avenir Next Ultra Light", size: 17)!
        ]

        let msgDialogue = MFMessageComposeViewController()
        
        if let phone = phone {
            msgDialogue.recipients = [phone]
        }
        msgDialogue.body = "\(peer.publicKey.toAuthorized()) \(peer.email)"
        msgDialogue.messageComposeDelegate = self
        
        
        let authorizedKey = peer.publicKey.toAuthorized()
        
        if let pkData = "\(authorizedKey) \(peer.email)".data(using: String.Encoding.utf8) {
            msgDialogue.addAttachmentData(pkData, typeIdentifier: "kr", filename: "publickey.kr")
        }
        
        if let url = URL(string: Link.publicKeyImport()) {
            msgDialogue.addAttachmentURL(url, withAlternateFilename: "publickey.kr")
        }

        msgDialogue.body = "Import my public key with kryptonite!"

        
        Resources.makeAppearences()
        
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
            mailDialogue.addAttachmentData(pkData, mimeType: "", fileName: "publickey.kr")
        }
        
        mailDialogue.setMessageBody("<a href=\"\(Link.publicKeyImport())\"> Import my public key with kryptonite by tapping here</a> or download the public key attached below. ", isHTML: true)

        

        Resources.makeAppearences()

        return mailDialogue
    }
    
    func copyDialogue(for peer:Peer) {
        UIPasteboard.general.string = "\(peer.publicKey.toAuthorized()) \(peer.email)"
        performSegue(withIdentifier: "showSuccess", sender: nil)
    }
    
    func otherDialogue(for peer:Peer) -> UIViewController {
        let otherDialogue = UIActivityViewController(activityItems: ["\(peer.publicKey.toAuthorized()) \(peer.email)"
], applicationActivities: nil)
        return otherDialogue
    }
    
    //MARK: Delegates
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
}

