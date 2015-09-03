//
//  Genre.swift
//  Restler
//
//  Created by Rasmus Kildevæld   on 03/09/15.
//  Copyright (c) 2015 CocoaPods. All rights reserved.
//

import Foundation
import CoreData

@objc(Genre)
class Genre: NSManagedObject {

    @NSManaged var desc: String
    @NSManaged var name: String
    @NSManaged var id: NSNumber

}
