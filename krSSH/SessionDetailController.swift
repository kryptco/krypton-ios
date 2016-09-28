//
//  SessionDetailController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class SessionDetailController: KRBaseTableController {

    @IBOutlet var deviceNameLabel:UILabel!
    @IBOutlet var lastAccessLabel:UILabel!

    @IBOutlet var revokeButton:UIButton!

    var logs:[SignatureLog] = []
    var session:Session?
    
    var timer:Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Details"
        
        if let session = session {
            deviceNameLabel.text = session.pairing.name.uppercased()
            
            logs = LogManager.shared.all.filter({ $0.session == session.id }).sorted(by: { $0.date > $1.date })
            lastAccessLabel.text =  "Active as of " + (logs.first?.date.timeAgo() ?? session.created.timeAgo())
            
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SessionDetailController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    dynamic func newLogLine() {
        log("new log")
        guard let session = session else {
            return
        }
        
        dispatchAsync {
            self.logs = LogManager.shared.all.filter({ $0.session == session.id }).sorted(by: { $0.date > $1.date })
            
            dispatchMain {                
                self.lastAccessLabel.text =  "Active as of " + (self.logs.first?.date.timeAgo() ?? session.created.timeAgo())
                self.tableView.reloadData()
            }
        }

    }


    //MARK: Revoke
    
    @IBAction func onRevokeSelected() {
        revokeButton.backgroundColor = UIColor(hex: 0xFC484C)
        revokeButton.titleLabel?.textColor = UIColor.white
    }
    
    @IBAction func onRevokeUnselected() {
        revokeButton.backgroundColor = UIColor.white
        revokeButton.titleLabel?.textColor = UIColor(hex: 0xFC484C)
    }
    
    @IBAction func revokeTapped() {
        if let session = session {
            SessionManager.shared.remove(session: session)
            Silo.shared.remove(session: session)
        }
        let _ = self.navigationController?.popViewController(animated: true)
    }

    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Access Logs"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell") as! LogCell
        cell.set(log: logs[indexPath.row])
        return cell
    }
 
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
        
    }
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

}
