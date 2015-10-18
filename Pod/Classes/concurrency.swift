//
//  concurrency.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 30/09/15.
//
//

import Foundation


func dispatch_main(fn:() -> Void) {
    dispatch_async(dispatch_get_main_queue(), fn)
}

func synchronized (obj:NSObject, fn:() -> Void) {
    objc_sync_enter(obj)
    fn()
    objc_sync_exit(obj)
}

func synchronized<T>(obj:NSObject, fn:() -> T) -> T {
    let result: T
    objc_sync_enter(obj)
    result = fn()
    objc_sync_exit(obj)
    return result
}
