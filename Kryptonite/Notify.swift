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
import JSON

struct NonPresentableRequestError:Error {}

extension Request {
    /**
        An identifier to group identical requests by
        only acceptable for SSH signature requests
     */
    var groupableNotificationIdentifer:String {
        switch self.body {
        case .ssh(let sshSign):
            return sshSign.display
        default:
            return self.id
        }
    }
}

/**
    Show an auto-approved local notification
    group identical requests with the number of times they appeared.
    i.e.: "root@server.com (5)"
 */
typealias GroupableRequestNotificationIdentifier = String
extension GroupableRequestNotificationIdentifier {
    init(request:Request, session:Session) {
        self = "\(session.id)_\(request.groupableNotificationIdentifer)"
    }
    
    func with(count:Int) -> String {
        return "\(self)_\(count)"
    }
}


/**
    Handle presenting local request notifications to the user.
    presents:
        - approvable requests: need users response
        - auto-approved: policy settings already approved, notify user it happened
 */
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
        
        guard request.body.isApprovable else {
            log("trying to present approval notification for non approvable request type", .error)
            return
        }
        
        let noteTitle = "Request from \(session.pairing.displayName)"
        let (noteSubtitle, noteBody) = request.notificationDetails()

        
        if #available(iOS 10.0, *) {
            
            // check if request exists in pending notifications
            UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { (noteRequests) in
                for noteRequest in noteRequests {
                    guard   let requestObject = noteRequest.content.userInfo["request"] as? JSON.Object,
                        let deliveredRequest = try? Request(json: requestObject)
                        else {
                            continue
                    }
                    
                    // return if it's already there
                    if deliveredRequest.id == request.id {
                        return
                    }
                }
                
                // then, check if request exists in delivered notifications
                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { (notes) in
                    
                    for note in notes {
                        guard   let requestObject = note.request.content.userInfo["request"] as? JSON.Object,
                            let deliveredRequest = try? Request(json: requestObject)
                            else {
                                continue
                        }
                        
                        // return if it's already there
                        if deliveredRequest.id == request.id {
                            return
                        }
                    }
                    
                    // otherwise, no notificiation so display it:
                    let content = UNMutableNotificationContent()
                    content.title = noteTitle
                    content.subtitle = noteSubtitle
                    content.body = noteBody
                    content.sound = UNNotificationSound.default()
                    content.userInfo = ["session_display": session.pairing.displayName, "session_id": session.id, "request": request.object]
                    content.categoryIdentifier = request.authorizeCategoryIdentifier
                    content.threadIdentifier = request.id
                    
                    let noteId = request.id
                    log("pushing note with id: \(noteId)")
                    let request = UNNotificationRequest(identifier: noteId, content: content, trigger: nil)
                    
                    UNUserNotificationCenter.current().add(request) {(error) in
                        log("error firing notification: \(String(describing: error))")
                    }
                    
                })


            })

            
        } else {
            let notification = UILocalNotification()
            notification.alertTitle = "[\(noteSubtitle)] " + noteTitle
            notification.alertBody = noteBody
            notification.soundName = UILocalNotificationDefaultSoundName
            notification.category = request.authorizeCategoryIdentifier
            notification.userInfo = ["session_display": session.pairing.displayName, "session_id": session.id, "request": request.object]
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
    

    
    func presentApproved(request:Request, for session:Session) {
        
        guard request.body.isApprovable else {
            log("trying to present auto-approved notification for non approvable request type", .error)
            return
        }
        
        let noteTitle = "Approved request from \(session.pairing.displayName)"
        let (noteSubtitle, noteBody) = request.notificationDetails()

        if #available(iOS 10.0, *) {
            
            let noteId = GroupableRequestNotificationIdentifier(request: request, session:session)
            
            let content = UNMutableNotificationContent()
            content.title = noteTitle
            content.subtitle = noteSubtitle
            content.body = noteBody
            content.categoryIdentifier = request.autoAuthorizeCategoryIdentifier
            content.sound = UNNotificationSound.default()
            content.userInfo = ["session_display": session.pairing.displayName, "session_id": session.id, "request": request.object]

            
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
                    log("error firing notification: \(String(describing: error))")
                    self.noteMutex.lock {
                        self.pushedNotifications[noteId] = noteIndex+1
                    }
                }
            })


            
        } else {
            let notification = UILocalNotification()
            notification.alertTitle = "[\(noteSubtitle)] " + noteTitle
            notification.alertBody = noteBody
            notification.soundName = UILocalNotificationDefaultSoundName
            notification.category = request.autoAuthorizeCategoryIdentifier
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }

    }
    
    /**
        Show "error" local notification
    */
    func presentError(message:String, session:Session) {
        
        if UserRejectedError.isRejected(errorString: message) {
            return
        }
        
        let noteTitle = "Failed approval for \(session.pairing.displayName)"
        let noteBody = message
        
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.title = noteTitle
            content.body = noteBody
            content.sound = UNNotificationSound.default()
            
            let request = UNNotificationRequest(identifier: "\(session.id)_\(message.hash)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else {
            let notification = UILocalNotification()
            notification.alertTitle = noteTitle
            notification.alertBody = noteBody
            notification.soundName = UILocalNotificationDefaultSoundName
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
        
    }
    
    /**
        Tell the user that their PGP Key was exported
     */
    func presentExportedSignedPGPKey(identities:[String], fingerprint:Data) {
        
        let noteTitle = "Succesfully Exported PGP Public Key"
        let noteSubtitle = "\(fingerprint.hexPretty)"
        
        var noteBody = ""
        if identities.count == 1 {
            noteBody = "Signed user identity: \(identities[0])."
        } else if identities.count > 1 {
            noteBody = "Signed user identities: \(identities.joined(separator: ", "))."
        }
        
        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            content.title = noteTitle
            content.subtitle = noteSubtitle
            content.body = noteBody
            content.sound = UNNotificationSound.default()
            
            let request = UNNotificationRequest(identifier: "pgp_export", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else {
            let notification = UILocalNotification()
            notification.alertTitle = noteTitle
            notification.alertBody = noteBody
            notification.soundName = UILocalNotificationDefaultSoundName
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }

    }

}







