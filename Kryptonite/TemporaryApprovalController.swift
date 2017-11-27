//
//  TemporaryApprovalsController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TemporaryApprovalController:KRBaseTableController {
    
    var session:Session?
    
    var temporarilyApproved:[Policy.TemporarilyAllowedHost] = []
    
    var other:[(Policy.Settings.AllowedUntilType, TimeInterval)] = []

    enum Section:Int {
        case other = 0
        case hosts = 1
        
        static var all:[Section] { return  [.other, .hosts] }
        
        var title:String {
            switch self {
            case .other:
                return "Request Types"
            case .hosts:
                return "SSH - Temporarily Approved Hosts"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Auto-allow Settings"
        
        setPolicyLists()
        self.tableView.reloadData()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        tableView.tableFooterView = UIView()
    
    }
    
    func setPolicyLists() {
        guard let session = self.session else {
            return
        }
        
        let policySession = Policy.SessionSettings(for: session)
        temporarilyApproved = policySession.temporarilyApprovedSSHHosts
        
        other = []
        for type in Policy.Settings.AllowedUntilType.all {
            if let expires = policySession.settings.allowedUntil[type.key] {
                other.append((type, TimeInterval(expires)))
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.all.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        
        switch section {
        case .other:
            return other.count
        case .hosts:
            return temporarilyApproved.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        
        switch section {
        case .other:
            let cell = tableView.dequeueReusableCell(withIdentifier: "OtherApprovedTypeCell", for: indexPath) as? OtherApprovedTypeCell
            let (type, expires) = other[indexPath.row]
            cell?.set(type: type, expires: expires)
            return cell ?? UITableViewCell()

        case .hosts:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TemporarilyApprovedHostCell", for: indexPath) as? TemporarilyApprovedHostCell
            cell?.set(temporaryApprovedHost: temporarilyApproved[indexPath.row])
            return cell ?? UITableViewCell()
        }
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return ""
        }
        
        var count:Int
        switch section {
        case .other:
            count = other.count
        case .hosts:
            count = temporarilyApproved.count
        }
        
        if count == 0 {
            return ""
        }
        
        return section.title
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
    

    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }

        if editingStyle == .delete {
            
            if let session = self.session {
                
                switch section {
                case .other:
                    let (type, _) = other[indexPath.row]                    
                    Policy.SessionSettings(for: session).setAlwaysAsk(for: type)

                case .hosts:
                    let temporaryHost = temporarilyApproved[indexPath.row]
                    Policy.SessionSettings(for: session).setAlwaysAsk(for: temporaryHost.userAndHost)
                }

                setPolicyLists()
                tableView.deleteRows(at: [indexPath], with: .right)

                if temporarilyApproved.isEmpty && other.isEmpty {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            
        } else if editingStyle == .insert {
            return
        }
    }
}

extension Policy.Settings.AllowedUntilType {
    var title:String {
        switch self {
        case .ssh:
            return "SSH Logins"
        case .gitCommit:
            return "Git Commit Signatures"
        case .gitTag:
            return "Git Tag Signatures"
        case .blob:
            return "PGP Blob Signatures"
        }
    }
}

class OtherApprovedTypeCell:UITableViewCell {
    
    @IBOutlet weak var title:UILabel!
    @IBOutlet weak var timeLabel:UILabel!
    
    func set(type:Policy.Settings.AllowedUntilType, expires:TimeInterval) {
        title.text = type.title        
        timeLabel.text = Date(timeIntervalSince1970: expires).timeAgo(suffix: "")
    }
}
class TemporarilyApprovedHostCell:UITableViewCell {
    
    @IBOutlet weak var userAndHostLabel:UILabel!
    @IBOutlet weak var timeLabel:UILabel!
    
    func set(temporaryApprovedHost:Policy.TemporarilyAllowedHost) {
        userAndHostLabel.text = "\(temporaryApprovedHost.userAndHost.user) @ \(temporaryApprovedHost.userAndHost.hostname)"
        timeLabel.text = temporaryApprovedHost.expires.timeAgo(suffix: "")
    }
}
