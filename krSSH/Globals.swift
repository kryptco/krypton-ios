//
//  Globals.swift
//  krSSH
//
//  Created by Alex Grinman on 8/29/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import Foundation

//MARK: Keys
let KR_ENDPOINT_ARN_KEY = "aws_endpoint_arn_key"

//MARK: Functions
func isDebug() -> Bool {
    #if DEBUG
        return true
    #else
        return false
    #endif
}

//MARK: Dispatch
func dispatchMain(task:@escaping ()->Void) {
    DispatchQueue.main.async {
        task()
    }
}

func dispatchAsync(task:@escaping ()->Void) {
    DispatchQueue.global().async {
        task()
    }
    
}

func dispatchAfter(delay:Double, task:@escaping ()->Void) {
    
    let delay = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    
    DispatchQueue.main.asyncAfter(deadline: delay) {
        task()
    }
}



