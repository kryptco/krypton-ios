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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldPostAnalytics() {
            Analytics.postControllerView(clazz: String(describing: type(of: self)))
        }

        checkForUpdatesIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }

    func shouldPostAnalytics() -> Bool {
        return true
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldPostAnalytics() {
            Analytics.postControllerView(clazz: String(describing: type(of: self)))
        }
        checkForUpdatesIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        linkListener = nil
    }

    func shouldPostAnalytics() -> Bool {
        return true
    }

}

extension UIViewController {

    //MARK: Updates
    func checkForUpdatesIfNeeded() {
        Updater.checkForUpdateIfNeeded { (version) in
            guard let newVersion = version else {
                return
            }
            
            let alertController = UIAlertController(title: "New Version",
                                                    message: "Kryptonite v\(newVersion.string) is now available! Tap \"Download\" to go to the App Store to get the latest and greatest features.",
                                                    preferredStyle: .alert)
            
            let downloadAction = UIAlertAction(title: "Download", style: .default) { (alertAction) in
                
                if let appStoreURL = URL(string: Properties.appStoreURL) {
                    UIApplication.shared.openURL(appStoreURL)
                }
            }
            alertController.addAction(downloadAction)
            
            let cancelAction = UIAlertAction(title: "Later", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    //MARK: LinkHandler
    struct InvalidLinkError:Error{}
    func handle(link:Link) {
        
    }
}
