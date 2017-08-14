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
    case hour   = 3600
    case day    = 86400
    case week   = 604800
    
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
        return self.timeIntervalSinceNow.timeAgo(suffix: suffix)
    }
    
    func timeAgoLong(suffix:String = " ago") -> String {
        return self.timeIntervalSinceNow.timeAgoLong(suffix: suffix)
    }
    
    func trailingTimeAgo(suffix:String = " ago") -> String {
        let time = abs(self.timeIntervalSinceNow)
        let formatter = DateFormatter()
        
        if time < TimeSeconds.minute.rawValue {
            return "\(Int(time))s\(suffix)"
        } else if time < TimeSeconds.hour.rawValue {
            return "\(Int(time/TimeSeconds.minute.rawValue))m\(suffix)"
        } else if time < TimeSeconds.day.rawValue {
            formatter.dateStyle = DateFormatter.Style.none
            formatter.timeStyle = DateFormatter.Style.short
            return formatter.string(from: self)
        } else {
            formatter.dateStyle = DateFormatter.Style.short
            formatter.timeStyle = DateFormatter.Style.short
            return formatter.string(from: self)
        }
    }

    
    func shifted(by shiftedInterval:TimeInterval) -> Date {    
        return Date(timeIntervalSince1970: self.timeIntervalSince1970 + shiftedInterval)
    }
}

extension TimeInterval {
    func timeAgo(suffix:String = " ago") -> String {
        
        let time = abs(self)
        
        if time < TimeSeconds.minute.rawValue {
            return "\(Int(time))s\(suffix)"
        } else if time < TimeSeconds.hour.rawValue {
            return "\(Int(time/TimeSeconds.minute.rawValue))m\(suffix)"
        } else if time < 10*TimeSeconds.hour.rawValue {
            let hour = Int(time/TimeSeconds.hour.rawValue)
            let minutes = (Int(time) % Int(TimeSeconds.hour.rawValue))/Int(TimeSeconds.minute.rawValue)
            
            if minutes == 0 {
                return "\(hour)h\(suffix)"
            }

            return "\(hour)h \(minutes)m\(suffix)"
            
        } else if time < TimeSeconds.day.rawValue {
            return "\(Int(time/TimeSeconds.hour.rawValue))h\(suffix)"
        } else if time < TimeSeconds.week.rawValue {
            return "\(Int(time/TimeSeconds.day.rawValue))d\(suffix)"
        } else {
            return "\(Int(time/TimeSeconds.week.rawValue))wk\(suffix)"
        }
    }
    
    func timeAgoLong(suffix:String = " ago") -> String {
        
        let time = abs(self)
        
        if time < TimeSeconds.minute.rawValue {
            let seconds = Int(time)
            let secondsModifier = seconds == 1 ? "second" : "seconds"

            return "\(Int(time)) \(secondsModifier)\(suffix)"
            
        } else if time < TimeSeconds.hour.rawValue {
            let minutes = Int(time/TimeSeconds.minute.rawValue)
            let minutesModifier = minutes == 1 ? "minute" : "minutes"
            
            return "\(minutes) \(minutesModifier)\(suffix)"
        }
        else if time < 10*TimeSeconds.hour.rawValue {
            let hour = Int(time/TimeSeconds.hour.rawValue)
            let hoursModifier = hour == 1 ? "hour" : "hours"
            
            let minutes = (Int(time) % Int(TimeSeconds.hour.rawValue))/Int(TimeSeconds.minute.rawValue)
            
            if minutes == 0 {
                return "\(hour) \(hoursModifier)\(suffix)"
            }
            
            return "\(hour) \(hoursModifier) \(minutes)m\(suffix)"
        }
        else if time < TimeSeconds.day.rawValue {
            return "\(Int(time/TimeSeconds.hour.rawValue)) hours\(suffix)"
        }
        else if time < TimeSeconds.week.rawValue {
            let days = Int(time/TimeSeconds.day.rawValue)
            let daysModifier = days == 1 ? "day" : "days"
            
            return "\(days) \(daysModifier)\(suffix)"
        } else {
            let weeks = Int(time/TimeSeconds.week.rawValue)
            let weeksModifier = weeks == 1 ? "week" : "weeks"

            return "\(weeks) \(weeksModifier)\(suffix)"
        }
    }
}
