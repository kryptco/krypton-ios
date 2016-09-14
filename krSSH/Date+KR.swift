//
//  KR+Date.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation

enum TimeSeconds:Int {
    case second = 1
    case minute = 60
    case hour = 3600
    case day = 86400
}

extension Date {
    func hour() -> Int {
        //Return Hour
        return Calendar.current.component(.hour, from: self)
    }
    
    
    func minute() -> Int {
        //Return Minute
        return Calendar.current.component(.minute, from: self)
    }
    
    func toShortTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        let timeString = formatter.string(from: self)
        
        //Return Short Time String
        return timeString
    }
    
    func toLongTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .long
        formatter.dateStyle = .short
        let timeString = formatter.string(from: self)
        
        //Return Short Time String
        return timeString
    }
    
    func timeAgo() -> String {
        
        let time = -self.timeIntervalSinceNow
        
        if time < 60 {
            return "\(Int(time))s ago"
        } else if time < 3600 {
            return "\(Int(time/60))m ago"
        } else if time < 86400 {
            return "\(Int(time/3600))h ago"
        } else if time < 604800 {
            return "\(Int(time/86400))d ago"
        } else {
            return "\(Int(time/604800))wk ago"
        }
    }
 
}
