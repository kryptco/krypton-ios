//
//  Dispatch.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/23/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import Foundation

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
