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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup icons and borders
        keyIcon.FAIcon = FAType.FAKey
        tagIcon.FAIcon = FAType.FATag
    
        identiconView.image = IGSimpleIdenticon.from(keyLabel.text ?? "", size: CGSize(width: 100, height: 100))
        
        identiconView.setBorder(color: UIColor.white, cornerRadius: 30)
        //copyButton.setFAIcon(icon: FAType.FAShareAlt, forState: UIControlState.normal)
        //copyButton.setBorder(color: UIColor.app, borderWidth: 1.0)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    //MARK: TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Sessions"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: "SessionCell") as! SessionCell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90.0
    }
}
