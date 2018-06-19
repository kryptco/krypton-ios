//
//  U2FSessionDetailController.swift
//  Krypton
//
//  Created by Alex Grinman on 5/8/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import UIKit

class U2FSessionDetailController: KRBaseTableController, UITextFieldDelegate {
    
    @IBOutlet var deviceNameField:UITextField!
    @IBOutlet var lastAccessLabel:UILabel!
    
    @IBOutlet var revokeButton:UIButton!

    @IBOutlet var headerView:UIView!
    
    @IBOutlet var browserLogo:UIImageView!

    var logs:[U2FLog] = []
    var session:Session?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Details"
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 40
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SessionDetailController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)
        
        headerView.setBoxShadow()
        
        if let session = session {
            deviceNameField.text = session.pairing.displayName
            browserLogo.image = session.pairing.browser?.kind.logo
            updateLogs()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    // MARK: Updating logs
    func updateLogs() {
        guard let session = session else {
            return
        }
        
        browserLogo.image = session.pairing.browser?.kind.logo
        
        dispatchAsync {
            
            let lastLog:U2FLog? = LogManager.shared.fetchLatest(for: session.id)
            self.logs = LogManager.shared.fetch(for: session.id).sorted {
                $0.date > $1.date
            }

            
            dispatchMain {
                if let log = lastLog {
                    self.lastAccessLabel.text =  "Used " + log.date.timeAgo()
                } else {
                    self.lastAccessLabel.text = "No activity"
                }
                
                self.tableView.reloadData()
            }
        }
    }
    
    @objc dynamic func newLogLine() {
        log("new log")
        updateLogs()
    }
    
    
    //MARK: Revoke
    @IBAction func revokeTapped() {
        if let session = session {
            Analytics.postEvent(category: "device", action: "unpair", label: "detail")
            SessionManager.shared.remove(session: session)
            TransportControl.shared.remove(session: session)
        }
        
        UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred()
        
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    //MARK: Edit Device Session Name
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let session = session else {
            return
        }
        
        textField.text = session.pairing.displayName
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        guard let name = textField.text, let session = session else {
            return false
        }
        
        if name.isEmpty {
            return false
        } else {
            SessionManager.shared.changeSessionPairingName(of: session.id, to: name)
            self.session?.pairing.name = name
            deviceNameField.text = name
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if logs.isEmpty {
            return 1
        }
        
        return logs.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard !logs.isEmpty else {
            return tableView.dequeueReusableCell(withIdentifier: "EmptyU2FCell")!
        }
        
        let log = logs[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "U2FLogCell") as! U2FLogCell
        cell.set(log: log)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

class U2FLogCell:UITableViewCell {
    
    @IBOutlet weak var app:UILabel!
    @IBOutlet weak var action:UILabel!
    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var lastAccessed:UILabel!
    
    func set(log:U2FLog) {
        let known = KnownU2FApplication(for: log.appID)
        app.text = known?.displayName ?? log.appID.simpleDisplay
        action.text = log.isRegister ? "Registered" : "Logged in"
        lastAccessed.text = log.date.trailingTimeAgo()
        logo.image = known?.logo ?? #imageLiteral(resourceName: "default")
    }
}

extension Browser.Kind {
    var logo:UIImage {
        switch self {
        case .chrome:
            return #imageLiteral(resourceName: "chrome")
        case .safari:
            return #imageLiteral(resourceName: "safari")
        case .firefox:
            return #imageLiteral(resourceName: "firefox")
        }
    }
}
