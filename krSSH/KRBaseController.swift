//
//  KRBaseController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/26/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit


class KRBaseController: UIViewController {
    
    private var linkListener:LinkListener?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        linkListener = LinkListener(handle)
    }
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        linkListener = LinkListener(handle)
    }
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
    }
    
}



extension UIViewController {
    //MARK: LinkHandler
    struct InvalidLinkError:Error{}
    func handle(link:Link) {
        
        do {
            switch link.command {
            case .request:
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
            }
            
        } catch {
            self.showWarning(title: "Error", body: "Invalid app link.")
            return
        }
        
    }
}
