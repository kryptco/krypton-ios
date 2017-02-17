//
//  Notify.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/2/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

import UserNotifications

class Notify {
    private static var _shared:Notify?
    static var shared:Notify {
        if let sn = _shared {
            return sn
        }
        _shared = Notify()
        return _shared!
    }
    
    init() {}
    
    var pushedNotifications:[String:Int] = [:]
    var noteMutex = Mutex()
    
    func present(request:Request, for session:Session) {
        
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.body = "Request from \(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
            content.sound = UNNotificationSound.default()
            content.userInfo = ["session_id": session.id, "request": request.object]
            content.categoryIdentifier = Policy.authorizeCategory.identifier!
            content.threadIdentifier = request.id
            
            let noteId = request.id
            log("pushing note with id: \(noteId)")
            let request = UNNotificationRequest(identifier: noteId, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) {(error) in
               log("error firing notification: \(error)")
            }
            
        } else {
            let notification = UILocalNotification()
            notification.alertBody = "Request from \(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
            notification.soundName = UILocalNotificationDefaultSoundName
            notification.category = Policy.authorizeCategory.identifier
            notification.userInfo = ["session_id": session.id, "request": request.object]
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
    
    func presentApproved(request:Request, for session:Session) {
        
        if #available(iOS 10.0, *) {
            
            let noteId = RequestNotificationIdentifier(request: request, session:session)
            
            let content = UNMutableNotificationContent()
            content.body = "\(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
            content.sound = UNNotificationSound.default()
            content.userInfo = ["session_id": session.id, "request": request.object]
            content.categoryIdentifier = Policy.authorizeCategory.identifier!

            
            // check grouping index for same notification
            var noteIndex = 0
            noteMutex.lock()
            if let idx = pushedNotifications[noteId] {
                noteIndex = idx
            }
            noteMutex.unlock()
            
            let prevRequestIdentifier = noteId.with(count: noteIndex)
            
            // check if delivered notifications cleared
            UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { (notes) in
                
                // if notifications clear, reset count
                if notes.filter({ $0.request.identifier == prevRequestIdentifier}).isEmpty {
                    self.pushedNotifications.removeValue(forKey: noteId)
                    noteIndex = 0
                }
                // otherwise remove previous, update note body
                else {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prevRequestIdentifier])
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [prevRequestIdentifier])
                    content.body = "\(content.body) (\( noteIndex + 1))"
                    content.sound = UNNotificationSound(named: "")

                    
                }
                self.noteMutex.unlock()
                
                log("pushing note with id: \(noteId)")
                let request = UNNotificationRequest(identifier: noteId.with(count: noteIndex+1), content: content, trigger: nil)
                
                UNUserNotificationCenter.current().add(request) {(error) in
                    log("error firing notification: \(error)")
                    self.noteMutex.lock {
                        self.pushedNotifications[noteId] = noteIndex+1
                    }
                }
            })


            
        } else {
            let notification = UILocalNotification()
            
            notification.alertBody = "\(session.pairing.displayName): \(request.sign?.command ?? "SSH login")"
            notification.soundName = UILocalNotificationDefaultSoundName
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }

    }
}

typealias RequestNotificationIdentifier = String
extension RequestNotificationIdentifier {
    init(request:Request, session:Session) {
        self = "\(session.id)_\(request.sign?.command)"
    }
    
    func with(count:Int) -> String {
        return "\(self)_\(count)"
    }
}






