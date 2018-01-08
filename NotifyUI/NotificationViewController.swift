//
//  NotificationViewController.swift
//  NotifyUI
//
//  Created by Alex Grinman on 5/24/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import JSON

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    
    var detailController:ApproveDetailController?
    @IBOutlet weak var sessionLabel:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    enum InvalidNotificationError:Error {
        case badUserInfoData
    }
    
    func didReceive(_ notification: UNNotification) {
        do {
            guard let payload = notification.request.content.userInfo as? JSON.Object
            else {
                throw InvalidNotificationError.badUserInfoData
            }
            
            let unverifiedLocalRequest = try LocalNotificationAuthority.unverifiedLocalNotification(with: payload)
            sessionLabel.text = unverifiedLocalRequest.sessionName.uppercased()

            // set request specifcs
            self.detailController?.set(request: unverifiedLocalRequest.request)
            
        } catch  {
            log("error: \(error)")
            self.detailController?.set(request: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let detail = segue.destination as? ApproveDetailController
        {
            self.detailController = detail
            detail.view.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
}



