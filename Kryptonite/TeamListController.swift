//
//  TeamListController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/22/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import UIKit

class TeamListCell:UITableViewCell {
    
    @IBOutlet weak var teamLabel:UILabel!
    @IBOutlet weak var emailLabel:UILabel!
    
    func set(identity:Identity) {
        teamLabel.text = identity.team.name
        emailLabel.text = identity.email
    }
}

class TeamListController: KRBaseTableController {

    var identites:[Identity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        do {
            identites = try IdentityManager.shared.list()
            tableView.reloadData()
        } catch {
            self.showWarning(title: "Error", body: "Cannot load list of identities: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return identites.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TeamListCell", for: indexPath) as? TeamListCell
        else {
            return UITableViewCell()
        }
        
        cell.set(identity: identites[indexPath.row])

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let teamDetailController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamDetailController") as? TeamDetailController {
            teamDetailController.identity = identites[indexPath.row]
            self.navigationController?.pushViewController(teamDetailController, animated: true)
        }
    }

}
