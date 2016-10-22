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
                    let emailData = try link.properties["e"]?.fromBase64(),
                    let toEmail = String(data: emailData, encoding: String.Encoding.utf8)
                    else {
                        throw InvalidLinkError()
                }
                
                let me = try KeyManager.sharedInstance().getMe()
            
                dispatchMain {
                    self.present(self.emailDialogue(for: me, with: toEmail), animated: true, completion: nil)
                }
                
            default:
                break
      
            }
            
        } catch {
            self.showWarning(title: "Error", body: "Invalid app link.")
            return
        }
        
    }
}
