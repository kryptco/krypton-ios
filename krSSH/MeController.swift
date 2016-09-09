//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class MeController: UITableViewController {

    @IBOutlet var keyIcon:UILabel!
    @IBOutlet var keyLabel:UILabel!
    
    @IBOutlet var tagIcon:UILabel!
    @IBOutlet var tagLabel:UILabel!
    
    @IBOutlet var identiconView:UIImageView!

    @IBOutlet var copyButton:UIButton!
    @IBOutlet var linkButton:UIButton!

    var sessions:[Session] = []
    var logs:[SignatureLog] = []
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup icons and borders
        keyIcon.FAIcon = FAType.FAKey
        tagIcon.FAIcon = FAType.FATag
        
        identiconView.setBorder(color: UIColor.clear, cornerRadius: 25, borderWidth: 1.0)
        
        //copyButton.setFAIcon(icon: FAType.FAShareAlt, forState: UIControlState.normal)
        //copyButton.setBorder(color: UIColor.app, borderWidth: 1.0)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MeController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCurrentUser()
        
        sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
        tableView.reloadData()
    }
    
    dynamic func newLogLine() {
        logs = [SignatureLog](SessionManager.logs)
        tableView.reloadData()
    }
    
    func updateCurrentUser() {
        do {
            let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
            keyLabel.text = try publicKey.fingerprint().hexPretty
            tagLabel.text = try KeyManager.sharedInstance().getMe().email
            
            identiconView.image = IGSimpleIdenticon.from(publicKey, size: CGSize(width: 100, height: 100))
            
        } catch (let e) {
            log("error getting keypair: \(e)", LogType.error)
            showWarning(title: "Error loading keypair", body: "\(e)")
        }
    }
    
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if logs.isEmpty {
            return 1
        }
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Sessions"
        }
        return "Logs"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return sessions.count
        }
        return logs.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell") as! SessionCell
            cell.set(session: sessions[indexPath.row])
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell") as! LogCell
        cell.set(log: logs[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 60.0
        }
        return 30.0
    }
    
    
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row == 1 {
            return false
        }

        return true
     }
 
}
