//
//  KR+Date.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation

enum TimeSeconds:TimeInterval {
    case second = 1
    case minute = 60
    case hour = 3600
    case day = 86400
    case week = 604800
    
    func multiplied(by multiple:Double) -> TimeInterval {
        return self.rawValue*multiple
    }
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
    
    func timeAgo(suffix:String = " ago") -> String {
        
        let time = abs(self.timeIntervalSinceNow)
        
        if time < TimeSeconds.minute.rawValue {
            return "\(Int(time))s\(suffix)"
        } else if time < TimeSeconds.hour.rawValue {
            return "\(Int(time/TimeSeconds.minute.rawValue))m\(suffix)"
        } else if time < 10*TimeSeconds.hour.rawValue {
            let hour = Int(time/TimeSeconds.hour.rawValue)
            let minutes = (Int(time) % Int(TimeSeconds.hour.rawValue))/Int(TimeSeconds.minute.rawValue)
            return "\(hour)h \(minutes)m\(suffix)"
        } else if time < TimeSeconds.day.rawValue {
            return "\(Int(time/TimeSeconds.hour.rawValue))h\(suffix)"
        } else if time < TimeSeconds.week.rawValue {
            return "\(Int(time/TimeSeconds.day.rawValue))d\(suffix)"
        } else {
            return "\(Int(time/TimeSeconds.week.rawValue))wk\(suffix)"
        }
    }
 
}
