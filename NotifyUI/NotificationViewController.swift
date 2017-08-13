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
    
    
    @IBOutlet weak var sshContainerView:UIView!
    @IBOutlet weak var commitContainerView:UIView!
    @IBOutlet weak var tagContainerView:UIView!
    @IBOutlet weak var errorContainerView:UIView!

    
    var sshController:SSHLoginController?
    var commitController:CommitController?
    var tagController:TagController?
    var errorController:ErrorController?

    enum ContainerType {
        case ssh(String), commit(CommitInfo), tag(TagInfo), error(String)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    enum InvalidNotificationError:Error {
        case unexpectedRequestBody(String)
        case invalidData
    }
    
    func didReceive(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        do {
            guard   let sessionName = userInfo["session_display"] as? String,
                    let requestObject = userInfo["request"] as? JSON.Object
            else {
                    log("invalid notification", .error)
                    throw InvalidNotificationError.invalidData
            }
            
            // set request specifcs
            let request = try Request(json: requestObject)
            
            switch request.body {
            case .ssh(let signRequest):
                showView(type: .ssh(signRequest.display), deviceName: sessionName)
            case .git(let gitSignRequest):
                switch gitSignRequest.git {
                case .commit(let commit):
                    showView(type: ContainerType.commit(commit), deviceName: sessionName)
                case .tag(let tag):
                    showView(type: ContainerType.tag(tag), deviceName: sessionName)
                }
            case .createTeam, .me, .noOp, .unpair:
                throw InvalidNotificationError.unexpectedRequestBody(sessionName)
            }
            
        } catch InvalidNotificationError.unexpectedRequestBody(let deviceName) {
            showView(type: .error("Cannot display this request (unexpected request type)."), deviceName: deviceName)
        }
        catch {
            showView(type: .error("\(error)"), deviceName: "Unknown")
        }
    }
    
    func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        completion(UNNotificationContentExtensionResponseOption.dismissAndForwardAction)
    }
    
    func showView(type: ContainerType, deviceName:String) {
        
        switch type {
        case .ssh(let display):
            sshController?.set(display: display, sessionName: deviceName)
            removeAllBut(view: sshContainerView)
        case .commit(let commit):
            commitController?.set(commit: commit, sessionName: deviceName)
            removeAllBut(view: commitContainerView)
        case .tag(let tag):
            tagController?.set(tag: tag, sessionName: deviceName)
            removeAllBut(view: tagContainerView)
        case .error(let message):
            errorController?.set(errorMessage: message, deviceName: deviceName)
            removeAllBut(view: errorContainerView)

        }
    }
    
    func removeAllBut(view:UIView) {
        //errorContainerView.isHidden = true
        for v in [sshContainerView, commitContainerView, tagContainerView, errorContainerView] {
            guard v != view else {
                continue
            }
            
            v?.removeFromSuperview()
        }
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let ssh = segue.destination as? SSHLoginController {
            self.sshController = ssh
        } else if let commit = segue.destination as? CommitController {
            self.commitController = commit
        } else if let tag = segue.destination as? TagController {
            self.tagController = tag
        } else if let error = segue.destination as? ErrorController {
            self.errorController = error
        }
        
        segue.destination.view.translatesAutoresizingMaskIntoConstraints = false
    }

}

class ErrorController:UIViewController {
    
    @IBOutlet weak var deviceNameLabel:UILabel!
    @IBOutlet weak var errorLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
        
        errorLabel.text = ""
    }
    
    func set(errorMessage:String, deviceName:String) {
        errorLabel.text = errorMessage
        deviceNameLabel.text = deviceName.uppercased()
    }
    
}
class SSHLoginController:UIViewController {
    
    @IBOutlet weak var deviceNameLabel:UILabel!
    @IBOutlet weak var sshDisplayLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
        
        sshDisplayLabel.text = ""
        deviceNameLabel.text = ""
        
    }
    
    func set(display:String, sessionName:String) {
        sshDisplayLabel.text = display
        deviceNameLabel.text = sessionName.uppercased()
    }

}

class CommitController:UIViewController {
    
    @IBOutlet weak var deviceNameLabel:UILabel!

    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var authorLabel:UILabel!
    @IBOutlet weak var authorDateLabel:UILabel!
    
    @IBOutlet weak var committerLabel:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deviceNameLabel.text    = ""
        messageLabel.text       = ""
        authorLabel.text        = ""
        authorDateLabel.text    = ""
        committerLabel.text     = ""
    }
    
    func set(commit:CommitInfo, sessionName:String) {
        deviceNameLabel.text = sessionName.uppercased()
        
        messageLabel.text = commit.messageString
        
        let (author, date) = commit.author.userIdAndDateString
        let (committer, committerDate) = commit.committer.userIdAndDateString
        
        if author == committer {
            authorLabel.text = author
            authorDateLabel.text = date
            committerLabel.text = ""
        } else {            
            authorLabel.text = "A: " + author
            committerLabel.text = "C: " + committer
            authorDateLabel.text = committerDate
        }

    }
    
}

class TagController:UIViewController {
    
    @IBOutlet weak var deviceNameLabel:UILabel!
    @IBOutlet weak var messageLabel:UILabel!
    @IBOutlet weak var objectHashLabel:UILabel!
    @IBOutlet weak var tagLabel:UILabel!
    @IBOutlet weak var taggerLabel:UILabel!
    @IBOutlet weak var taggerDate:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deviceNameLabel.text = ""
        messageLabel.text = ""
        objectHashLabel.text = ""
        tagLabel.text = ""
        taggerLabel.text = ""
        taggerDate.text = ""

    }
    
    func set(tag:TagInfo, sessionName:String) {
        deviceNameLabel.text = sessionName.uppercased()

        messageLabel.text = tag.messageString
        objectHashLabel.text = tag.objectShortHash
        tagLabel.text = tag.tag
        let (tagger, date) = tag.tagger.userIdAndDateString
        taggerLabel.text = tagger
        taggerDate.text = date

    }
    
}




