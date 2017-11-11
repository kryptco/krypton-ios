//
//  TemporarilyApprovedHosts.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class TemporarilyApprovedHostsController:KRBaseTableController {
    
    var session:Session?
    var temporarilyApproved:[(VerifiedUserAndHostAuth, TimeInterval)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Auto-allowed Hosts"
        
        if let session = session {
            temporarilyApproved = Policy.getTemporarilyApprovedUserAndHostsAndExpirations(on: session)
        }
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 70
        tableView.tableFooterView = UIView()
    
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return temporarilyApproved.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TemporarilyApprovedHostCell", for: indexPath) as? TemporarilyApprovedHostCell
        cell?.set(temporaryApprovedHost: temporarilyApproved[indexPath.row])
        
        return cell ?? UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Remove"
    }
    

    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            if let session = self.session {
                Policy.removeTemporarilyAllowed(on: session, for: temporarilyApproved[indexPath.row].0)
                temporarilyApproved = Policy.getTemporarilyApprovedUserAndHostsAndExpirations(on: session)
                
                if temporarilyApproved.isEmpty {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            
            tableView.deleteRows(at: [indexPath], with: .right)
            tableView.reloadData()
        } else if editingStyle == .insert {
            return
        }
    }
}

class TemporarilyApprovedHostCell:UITableViewCell {
    
    @IBOutlet weak var userAndHostLabel:UILabel!
    @IBOutlet weak var timeLabel:UILabel!
    
    func set(temporaryApprovedHost:(VerifiedUserAndHostAuth, TimeInterval)) {
        let (userAndHost, timeInterval) = temporaryApprovedHost
        
        userAndHostLabel.text = "\(userAndHost.user) @ \(userAndHost.hostname)"
        timeLabel.text = Date(timeIntervalSince1970: timeInterval).timeAgo(suffix: "")
    }
}
