//
//  Log.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/31/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import Foundation

let DEFAULT_LOG_LEVEL = LogType.info

enum LogType:Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    func getIndicator() -> String {
        switch self {
        case .debug:
            return "⚪️"
        case .info:
            return "🔵"
        case .warning:
            return "⚠️"
        case .error:
            return "🔴"
        }
    }
}



func log(_ arg:CustomDebugStringConvertible?, _ type:LogType = .info, file:String = #file, function:String = #function, line:Int = #line) {
    let className = URL(fileURLWithPath: file).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    let statement = "[\(Date().timeIntervalSince1970)] - \(type.getIndicator()) \(className).\(function):\(line)> \(arg ?? "")"
    
    if Platform.isDebug && DEFAULT_LOG_LEVEL.rawValue <= type.rawValue {
        print(statement)
    }
}
