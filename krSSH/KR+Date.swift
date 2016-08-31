//
//  KR+Date.swift
//  krSSH
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import Foundation

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
}
