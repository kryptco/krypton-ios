//
//  ApproveOptions.swift
//  Krypton
//
//  Created by Alex Grinman on 11/10/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class ApproveOptionsCell:UITableViewCell {
    @IBOutlet weak var button:UIButton!
    
    
    var onSelect:((ApproveOptionsController.Option)->())?
    
    @IBAction func optionTapped() {
        guard let id = self.reuseIdentifier, let option = ApproveOptionsController.Option(rawValue: id) else {
            return
        }
        
        onSelect?(option)
    }
}

class ApproveOptionsController:UITableViewController {
    
    enum Option:String {
        case allow = "Allow"
        case allowOnce = "AllowOnce"
        case allowThis = "AllowThis"
        case allowAll = "AllowAll"
        case reject = "Reject"
        
        var identifier:String {
            return self.rawValue
        }
        
        var text:String {
            switch self {
            case .allow:
                return "Allow"
            case .allowOnce:
                return "Allow once"
            case .allowThis:
                return "Allow this host for 3 hours"
            case .allowAll:
                return "Allow all for 3 hours"
            case .reject:
                return "Reject"
            }
        }
        
    }
    
    var onSelect:((ApproveOptionsController.Option)->())?
    var doAdjustHeight:((CGFloat)->())?
    
    var options:[Option] = []
    
    let cellHeight:CGFloat = 70.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = cellHeight
        tableView.tableFooterView = nil
        
        self.tableView.reloadData()
    }
    
    func update() {
        self.tableView.reloadData()
        self.view.layoutIfNeeded()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doAdjustHeight?(cellHeight * CGFloat(options.count))
        
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: options[indexPath.row].identifier, for: indexPath) as? ApproveOptionsCell
        cell?.onSelect = onSelect
        
        return cell ?? UITableViewCell()
    }
    
}
