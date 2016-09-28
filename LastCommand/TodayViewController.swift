//
//  TodayViewController.swift
//  LastCommand
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
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
        let defaults = UserDefaults(suiteName: "group.lastcommand")

        let dateString = defaults?.string(forKey: "last_log_time") ?? "--"
        let command = defaults?.string(forKey: "last_log_command") ?? "--"
        let device = defaults?.string(forKey: "last_log_device") ?? "--"
        
        if let user = device.getUserOrNil() {
            commandLabel.text = "\(user) $ \(command)"
        } else {
            commandLabel.text = "- $ \(command)"
        }
        
        
        deviceLabel.text = device.uppercased()
        timeLabel.text = dateString
    }
    
}
