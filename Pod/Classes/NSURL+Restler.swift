//
//  NSURL+Restler.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 01/10/15.
//
//

import Foundation


extension NSURL {
    func URLByStrippingQuery () -> NSURL {
        let str = self.absoluteString
        let i = str.characters.indexOf("?")
        if i != nil {
            return NSURL(string: str.substringToIndex(i!))!
        }
        return self
    }
}