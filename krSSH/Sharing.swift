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
    
    func dialogue(for peer:Peer, by kind:Kind) -> UIViewController {
        switch kind {
        case .text(let phone):
            return textDialogue(for: peer, with: phone)
        case .email(let address):
            return emailDialogue(for: peer, with: address)
        case .copy:
            return copyDialogue(for: peer)
        case .other:
            return otherDialogue(for: peer)
        }
    }
    
    func textDialogue(for peer:Peer, with phone:String?) -> UIViewController {
        let msgDialogue = MFMessageComposeViewController()
        
        if let phone = phone {
            msgDialogue.recipients = [phone]
        }
        msgDialogue.body = "\(peer.publicKey) <\(peer.email)>"
        msgDialogue.delegate = self
        return msgDialogue
    }
    
    func emailDialogue(for peer:Peer, with email:String?) -> UIViewController {
        let mailDialogue = MFMailComposeViewController()
        
        if let email = email {
            mailDialogue.setToRecipients([email])
        }
    
        mailDialogue.setSubject("My SSH Public Key")
        mailDialogue.setMessageBody("\(peer.publicKey) <\(peer.email)>", isHTML: false)
        mailDialogue.delegate = self

        return mailDialogue
    }
    
    func copyDialogue(for peer:Peer) -> UIViewController {
        UIPasteboard.general.string = "\(peer.publicKey) <\(peer.email)>"
        return Resources.Storyboard.Main.instantiateViewController(withIdentifier: "SuccessController")
    }
    
    func otherDialogue(for peer:Peer) -> UIViewController {
        let otherDialogue = UIActivityViewController(activityItems: ["\(peer.publicKey) <\(peer.email)>"
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

