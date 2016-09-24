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
    
    enum Kind {
        case text(String?), email(String?), copy, other
    }
    
    func textDialogue(for peer:Peer, with phone:String?, and publicKeyWire:String) -> UIViewController {
        
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
        msgDialogue.body = "\(publicKeyWire) <\(peer.email)>"
        msgDialogue.messageComposeDelegate = self
        
        
        Resources.makeAppearences()
        
        return msgDialogue
    }
    
    func emailDialogue(for peer:Peer, with email:String?, and publicKeyWire:String) -> UIViewController {
        let mailDialogue = MFMailComposeViewController()
        if let email = email {
            mailDialogue.setToRecipients([email])
        }
    
        mailDialogue.setSubject("My SSH Public Key")
        mailDialogue.setMessageBody("\(publicKeyWire) <\(peer.email)>", isHTML: false)
        mailDialogue.mailComposeDelegate = self

        return mailDialogue
    }
    
    func copyDialogue(for peer:Peer, and publicKeyWire:String) {
        UIPasteboard.general.string = "\(publicKeyWire) <\(peer.email)>"
        performSegue(withIdentifier: "showSuccess", sender: nil)
    }
    
    func otherDialogue(for peer:Peer, and publicKeyWire:String) -> UIViewController {
        let otherDialogue = UIActivityViewController(activityItems: ["\(publicKeyWire) <\(peer.email)>"
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

