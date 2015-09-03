//
//  Concert.swift
//  Restler
//
//  Created by Rasmus Kildevæld   on 10/07/15.
//  Copyright (c) 2015 CocoaPods. All rights reserved.
//

import Foundation
import CoreData
import DStack

@objc(Concert)
class Concert: NSManagedObject, NamedEntity {
    static let entityName: String = "Concert"
    @NSManaged var id: NSNumber
    @NSManaged var title: String
    @NSManaged var start: NSDate
    @NSManaged var finish: NSDate
    @NSManaged var desc: String?
    @NSManaged var website: String?
}
