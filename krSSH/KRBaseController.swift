//
//  KRBaseController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/26/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit


class KRBaseController: UIViewController {
    
    private var linkListener:LinkListener?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
        linkListener = LinkListener(handle)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }
 
    
}

class KRBaseTabController: UITabBarController {
    
    private var linkListener:LinkListener?
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
        linkListener = LinkListener(handle)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }
    
}

class KRBaseTableController: UITableViewController {
    
    private var linkListener:LinkListener?
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
        linkListener = LinkListener(handle)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }
    
}

class KRBasePageController: UIPageViewController {
    
    private var linkListener:LinkListener?
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
        linkListener = LinkListener(handle)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }
    
}




extension UIViewController {
    
    var foregroundNotificationName:NSNotification.Name {
        return NSNotification.Name(rawValue: "on_foreground_view_will_appear")
    }

    
    //MARK: LinkHandler
    struct InvalidLinkError:Error{}
    func handle(link:Link) {
        
        do {
            switch link.command {
            case .request where link.type == .kr:
                guard
                    let emailData = try link.properties["r"]?.fromBase64(),
                    let toEmail = String(data: emailData, encoding: String.Encoding.utf8)
                    else {
                        throw InvalidLinkError()
                }
                
                let me = try KeyManager.sharedInstance().getMe()
            
                dispatchMain {
                    self.present(self.emailDialogue(for: me, with: toEmail), animated: true, completion: nil)
                }
            case .import where link.type == .kr:
                guard
                    let publicKeyWire = try link.properties["pk"]?.fromBase64(),
                    let emailData = try link.properties["e"]?.fromBase64(),
                    let email = String(data: emailData, encoding: String.Encoding.utf8)
                else {
                        throw InvalidLinkError()
                }
                
                let peer = Peer(email: email, fingerprint: publicKeyWire.fingerprint(), publicKey: publicKeyWire)
                
                PeerManager.shared.add(peer: peer)
                
                dispatchAfter(delay: 1.0, task: { 
                    dispatchMain {
                        if let successVC = self.storyboard?.instantiateViewController(withIdentifier: "SuccessController") as? SuccessController
                        {
                            successVC.hudText = "Added \(email)'s Public Key!"
                            successVC.modalPresentationStyle = .overCurrentContext
                            self.present(successVC, animated: true, completion: nil)
                        }
                        
                    }
                })
                
            case .none where link.type == .file:
                let pubKeyFile = try String(contentsOf: link.url, encoding: String.Encoding.utf8)
                let components = try pubKeyFile.byRemovingComment()
                let pubKeyWire = try components.0.toWire()
                let peer = Peer(email: components.1, fingerprint: pubKeyWire.fingerprint(), publicKey: pubKeyWire)
                
                PeerManager.shared.add(peer: peer)
                
                dispatchAfter(delay: 1.0, task: {
                    dispatchMain {
                        if let successVC = self.storyboard?.instantiateViewController(withIdentifier: "SuccessController") as? SuccessController
                        {
                            successVC.hudText = "Added \(peer.email)'s Public Key!"
                            successVC.modalPresentationStyle = .overCurrentContext
                            self.present(successVC, animated: true, completion: nil)
                        }
                        
                    }
                })                
            default:
                break
      
            }
            
        } catch {
            self.showWarning(title: "Error", body: "Invalid app link.")
            return
        }
        
    }
}
