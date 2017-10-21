//
//  AppDelegate+Links.swift
//  Kryptonite
//
//  Created by Remi Robert on 21/10/2017.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit

extension AppDelegate {

    //MARK: Links

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {

        guard let link = Link(url: url) else {
            log("invalid kr url: \(url)", .error)
            return false
        }

        self.pendingLink = link
        NotificationCenter.default.post(name: Link.notificationName, object: link, userInfo: nil)
        return true
    }
}
