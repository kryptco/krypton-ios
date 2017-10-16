//
//  MeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class SessionsController: KRBaseController, UITableViewDelegate, UITableViewDataSource {
    

    var sessions:[Session] = []
    
    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var emptyView:UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        //tableView.tableFooterView = UIView()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SessionsController.newLogLine), name: NSNotification.Name(rawValue: "new_log"), object: nil)


        dispatchAsync {
            self.sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })

            dispatchMain{
                self.tableView.reloadData()

                guard !self.sessions.isEmpty else {
                    self.emptyView.isHidden = false
                    self.tableView.isHidden = true
                    return
                }
                
                self.emptyView.isHidden = true
                self.tableView.isHidden = false

            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    
    
    @objc dynamic func newLogLine() {
        dispatchAsync {
            self.sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
            dispatchMain{ self.tableView.reloadData() }
        }
    }
 
    
    @IBAction func addDevice() {
        (self.parent as? UITabBarController)?.selectedIndex = 1
    }
    
    //MARK: TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell") as! SessionCell
        cell.set(session: sessions[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140.0

    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showSignatureLogs", sender: sessions[indexPath.row])
    }
    
    
     // Override to support conditional editing of the table view.
     func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
     }
    

     // Override to support editing the table view.
     func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            Analytics.postEvent(category: "device", action: "unpair", label: "slide")
            SessionManager.shared.remove(session: sessions[indexPath.row])
            TransportControl.shared.remove(session: sessions[indexPath.row])
            sessions = SessionManager.shared.all.sorted(by: {$0.created > $1.created })
            
            self.emptyView.isHidden = !sessions.isEmpty
            self.tableView.isHidden = sessions.isEmpty

            tableView.deleteRows(at: [indexPath], with: .right)
            tableView.reloadData()
        } else if editingStyle == .insert {
            return
        }
     }
    
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Unpair"
    }
    

    //MARK: Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let detailController = segue.destination as? SessionDetailController,
            let session = sender as? Session  {
            detailController.session = session
        }
    }
 
}
