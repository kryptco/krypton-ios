//
//  TodayViewController.swift
//  LastCommand
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding {
    
    @IBOutlet weak var timeLabel:UILabel!
    @IBOutlet weak var commandLabel:UILabel!
    @IBOutlet weak var deviceLabel:UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        update()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        update()
        completionHandler(NCUpdateResult.newData)
    }
    
    func update() {
        print("update called")
        let defaults = UserDefaults.group

        let dateString = defaults?.string(forKey: "last_log_time") ?? "--"
        let command = defaults?.string(forKey: "last_log_command") ?? "--"
        let device = defaults?.string(forKey: "last_log_device") ?? "--"
        
        commandLabel.text = "$ \(command)"
        deviceLabel.text = device.removeDotLocal().uppercased()
        timeLabel.text = dateString
    }
    
}
