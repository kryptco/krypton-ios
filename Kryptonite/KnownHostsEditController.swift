//
//  KnownHostsEditController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 4/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class KnownHostsEditController:KRBaseTableController {
    
    @IBOutlet var emptyView:UIView!

    var knownHosts:[KnownHost] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.tableFooterView = UIView()

        do {
            knownHosts = try KnownHostManager.shared.fetchAll()
            self.tableView.reloadData()
        } catch {
            self.showWarning(title: "Error", body: "Failed to load known hosts. Please try again.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(KnownHostsEditController.newKnownHost), name: NSNotification.Name(rawValue: "new_known_host"), object: nil)
        
        self.addRemoveEmptyViewAsNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "new_known_host"), object: nil)
    }

    
    @objc dynamic func newKnownHost() {
        dispatchMain {
            do {
                self.knownHosts = try KnownHostManager.shared.fetchAll()
                self.tableView.reloadData()
                self.addRemoveEmptyViewAsNeeded()
            } catch {
                log("error fetching known hosts: \(error)")
            }
        }
 
    }
    
    func addRemoveEmptyViewAsNeeded() {
        emptyView.removeFromSuperview()

        if self.knownHosts.isEmpty {
            emptyView.center = self.view.center
            self.view.addSubview(emptyView)
        }

    }

    //MARK: TableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return knownHosts.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: KnownHostCell.identifier) as! KnownHostCell
        cell.set(knownHost: knownHosts[indexPath.row])
        return cell

    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .destructive, title: "Remove") { (action, path) in
            KnownHostManager.shared.delete(self.knownHosts[indexPath.row])
            self.knownHosts.remove(at: indexPath.row)
            self.tableView.reloadData()
            self.addRemoveEmptyViewAsNeeded()
            
            Analytics.postEvent(category: "known_host", action: "delete")

        }
        action.backgroundColor = UIColor.reject
        return [action]
    }
}

class KnownHostCell:UITableViewCell {
    
    static let identifier = "KnownHostCell"
    override var reuseIdentifier: String? { return KnownHostCell.identifier }
    
    @IBOutlet var hostNameLabel:UILabel!
    @IBOutlet var fingerprintLabel:UILabel!
    @IBOutlet var dateLabel:UILabel!

    func set(knownHost:KnownHost) {
        hostNameLabel.text = knownHost.hostName
        dateLabel.text = knownHost.dateAdded.toShortTimeString()
        
        do {
            fingerprintLabel.text = try knownHost.publicKey.fromBase64().SHA256.toBase64()
        } catch {
            fingerprintLabel.text = "<error decoding>"
        }
    }
}
