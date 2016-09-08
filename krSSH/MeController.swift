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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup icons and borders
        keyIcon.FAIcon = FAType.FAKey
        tagIcon.FAIcon = FAType.FATag
        
        identiconView.setBorder(color: UIColor.clear, cornerRadius: 25, borderWidth: 1.0)
        
        //copyButton.setFAIcon(icon: FAType.FAShareAlt, forState: UIControlState.normal)
        //copyButton.setBorder(color: UIColor.app, borderWidth: 1.0)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCurrentUser()
        
        sessions = SessionManager.sharedInstance().all.sorted(by: {$0.created > $1.created })
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
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Sessions"
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
        return 64.0
    }
}
