//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class SessionsController: UITableViewController {
    

    var sessions:[Session] = []
    
    //@IBOutlet weak var addButton:UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(SessionsController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCurrentUser()
        
       // addButton.setBorder(color: UIColor.clear, cornerRadius: 10, borderWidth: 1.0)
        sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
        tableView.reloadData()
    }
    
    dynamic func newLogLine() {
        dispatchMain {
            self.sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
            self.tableView.reloadData()
        }
    }
    
    func updateCurrentUser() {
    }
    
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell") as! SessionCell
        cell.set(session: sessions[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0

    }
    
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
     }
    

     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            SessionManager.shared.remove(session: sessions[indexPath.row])
            Silo.shared.remove(session: sessions[0])
            sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
            
            tableView.deleteRows(at: [indexPath], with: .right)
            tableView.reloadData()
        } else if editingStyle == .insert {
            return
        }
     }
 
 
}
