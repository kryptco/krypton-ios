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
        case badRequest
        case badSessionDisplay
    }
    
    func didReceive(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        do {
            guard   let sessionName = userInfo["session_display"] as? String
            else {
                    log("invalid notification", .error)
                    throw InvalidNotificationError.badSessionDisplay
            }
            
            sessionLabel.text = sessionName.uppercased()

            guard let requestObject = userInfo["request"] as? JSON.Object else {
                throw InvalidNotificationError.badRequest
            }

            // set request specifcs
            let request = try Request(json: requestObject)
            self.detailController?.set(request: request)
            
        } catch InvalidNotificationError.badSessionDisplay {
            sessionLabel.text = "Unknown!"
            sessionLabel.textColor = UIColor.reject
            self.detailController?.set(request: nil)

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



