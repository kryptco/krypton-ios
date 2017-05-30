//
//  SessionDetailController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit

class SessionDetailController: KRBaseTableController, UITextFieldDelegate {

    @IBOutlet var deviceNameField:UITextField!
    @IBOutlet var lastAccessLabel:UILabel!

    @IBOutlet var revokeButton:UIButton!
    @IBOutlet var unknownHostSwitch:UISwitch!

    @IBOutlet var headerView:UIView!

    @IBOutlet weak var approvalSegmentedControl:UISegmentedControl!

    @IBOutlet var sshLogButton:UIButton!
    @IBOutlet var gitLogButton:UIButton!

    enum ApprovalControl:Int {
        case on = 0
        case timed = 1
        case off = 2
    }
    
    enum LogType {
        case ssh, git
    }
    
    var logType = LogType.ssh
    
    var logs:[LogStatement] = []
    var session:Session?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Details"
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 40
        
        
        if let font = UIFont(name: "AvenirNext-Bold", size: 12) {
            approvalSegmentedControl.setTitleTextAttributes([
                NSFontAttributeName: font,
            ], for: UIControlState.normal)
        }

        
        if let session = session {
            deviceNameField.text = session.pairing.displayName.uppercased()
            unknownHostSwitch.isOn = Policy.needsUnknownHostApproval(for: session)
            
            if let lastLog = LogManager.shared.fetchCompleteLatest(for: session.id) {
                switch lastLog {
                case is SSHSignatureLog:
                    logType = .ssh
                case is CommitSignatureLog, is TagSignatureLog:
                    logType = .git
                default:
                    break
                }
                
                showLogs(for: logType)
            }

        
            updateLogs()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SessionDetailController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)

        headerView.layer.shadowColor = UIColor.black.cgColor
        headerView.layer.shadowOffset = CGSize(width: 0, height: 0)
        headerView.layer.shadowOpacity = 0.175
        headerView.layer.shadowRadius = 3
        headerView.layer.masksToBounds = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Changing Log Type
    
    @IBAction func sshLogsTapepd() {
        let type = LogType.ssh
        showLogs(for: type)
        logType = type
        updateLogs()
    }
    
    @IBAction func gitLogsTapepd() {
        let type = LogType.git
        showLogs(for: type)
        logType = type
        updateLogs()
    }
    
    func showLogs(for type:LogType) {
        switch type {
        case .ssh:
            gitLogButton.alpha = 0.5
            sshLogButton.alpha = 1.0
        case .git:
            sshLogButton.alpha = 0.5
            gitLogButton.alpha = 1.0
        }
    }
    
    // MARK: Updating logs
    func updateLogs() {
        guard let session = session else {
            return
        }
        
        dispatchAsync {
            
            let lastLog = LogManager.shared.fetchCompleteLatest(for: session.id)
            
            switch self.logType {
            case .ssh:
                let sshLogs:[SSHSignatureLog] = LogManager.shared.fetch(for: session.id)
                self.logs = sshLogs

            case .git:
                let commitLogs:[CommitSignatureLog] = LogManager.shared.fetch(for: session.id)
                let tagLogs:[TagSignatureLog] = LogManager.shared.fetch(for: session.id)

                self.logs = ((commitLogs as [LogStatement]) + (tagLogs as [LogStatement])).sorted {
                    $0.date > $1.date
                }
            }
            
            dispatchMain {
                if let log = lastLog {
                    self.lastAccessLabel.text =  "Active as of " + log.date.timeAgo()
                } else {
                    self.lastAccessLabel.text = ""
                }
                self.tableView.reloadData()
            }
        }
        
        dispatchMain {
            self.updateApprovalControl(session: session)
        }
    }
    
    dynamic func newLogLine() {
        log("new log")
        updateLogs()
    }

    @IBAction func userApprovalSettingChanged(sender:UISegmentedControl) {
        guard let session = session, let approvalControlType = ApprovalControl(rawValue: sender.selectedSegmentIndex) else {
            log("unknown session or approval segmented control index", .error)
            return
        }
        
        switch approvalControlType {
        case .on:
            Analytics.postEvent(category: "manual approval", action: String(true))
            Policy.set(needsUserApproval: true, for: session)

        case .timed:
            Analytics.postEvent(category: "manual approval", action: "time", value: UInt(Policy.Interval.threeHours.rawValue))
            Policy.allow(session: session, for: Policy.Interval.threeHours)

        case .off:
            Analytics.postEvent(category: "manual approval", action: String(false))
            Policy.set(needsUserApproval: false, for: session)
        }
        
        approvalSegmentedControl.setTitle("Don't ask for 3hrs", forSegmentAt: ApprovalControl.timed.rawValue)
    }

    @IBAction func unknownHostApprovalChanged(sender:UISwitch) {
        guard let session = session else {
            return
        }
        
        Policy.set(manualUnknownHostApprovals: sender.isOn, for: session)
    }

    //MARK: Revoke
    @IBAction func revokeTapped() {
        if let session = session {
            Analytics.postEvent(category: "device", action: "unpair", label: "detail")
            SessionManager.shared.remove(session: session)
            TransportControl.shared.remove(session: session)
        }
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    func updateApprovalControl(session:Session) {
        if Policy.needsUserApproval(for: session)  {
            approvalSegmentedControl.selectedSegmentIndex = ApprovalControl.on.rawValue
        }
        else if let remaining = Policy.approvalTimeRemaining(for: session) {
            approvalSegmentedControl.selectedSegmentIndex = 1
            approvalSegmentedControl.setTitle("Don't ask for \(remaining)", forSegmentAt: ApprovalControl.timed.rawValue)
        }
        else {
            approvalSegmentedControl.selectedSegmentIndex = ApprovalControl.off.rawValue
        }
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
            deviceNameField.text = name.uppercased()
        }
        
        textField.resignFirstResponder()
        return true
    }


    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let log = logs[indexPath.row]
        
        if let sshLog = log as? SSHSignatureLog {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SSHLogCell") as! SSHLogCell
            cell.set(log: sshLog)
            
            return cell
            
        } else if let commitLog = log as? CommitSignatureLog {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GitCommitLogCell") as! GitCommitLogCell
            
            var previous:CommitSignatureLog?
            var next:CommitSignatureLog?
            
            if (0 ..< logs.count).contains(indexPath.row - 1) {
                next = logs[indexPath.row - 1] as? CommitSignatureLog
            }

            if (0 ..< logs.count).contains(indexPath.row + 1) {
                previous = logs[indexPath.row + 1] as? CommitSignatureLog
            }
            cell.set(log: commitLog, previousLog: previous, nextLog: next)
            
            return cell
            
        } else if let tagLog = log as? TagSignatureLog {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GitTagLogCell") as! GitTagLogCell
            cell.set(log: tagLog)
            
            return cell
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let log = logs[indexPath.row]
        
        if let commitLog = log as? CommitSignatureLog {
            self.performSegue(withIdentifier: "showCommitLogDetail", sender: commitLog)
            
        } else if let _ = log as? TagSignatureLog {
        }
    }
 
//    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return 80.0
//        
//    }
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let commitLog = sender as? CommitSignatureLog,
            let logDetailController = segue.destination as? CommitLogDetailController
        {
            logDetailController.commitLog = commitLog
        }
    }

}
