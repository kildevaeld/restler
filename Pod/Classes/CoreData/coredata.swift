//
//  coredata.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 10/07/15.
//
//

import Foundation
import Restler
import CoreData
import DStack
import Bolts
import SwiftyJSON


public extension Double {
    public var asDate : NSDate {
        return NSDate(timeIntervalSince1970: self)
    }
}

public extension String {
    public var asURL : NSURL? {
        return NSURL(string: self)
    }
    
    public var asPredicate: NSPredicate? {
        return NSPredicate(format:self)
    }
}


public typealias ManagedResourceCompletetion = (context: NSManagedObjectContext, value: JSON, complete:ResourceCompletion) -> Void

public class EntityDescriptor : ResponseDescriptor {
    private let mapper: ManagedResourceCompletetion?
    
    public let context: NSManagedObjectContext
    public var batchSize = 100
    public init (context: NSManagedObjectContext) {
        self.context = context
        self.mapper = nil
    }
    
    public init(_ context: NSManagedObjectContext, map: ManagedResourceCompletetion) {
        self.context = context
        self.mapper = map
    }
    
    public func respond(data: AnyObject) -> BFTask {
        let promise = BFTaskCompletionSource()
        
        let dict = data as? NSDictionary
        
        if dict == nil {
            Restler.log.debug("could not cast data to dictionary")
            return BFTask(result: nil)
        }
        
        let json : JSON = JSON(dict!)
        
        self.mapValue(json, complete: { (error, data) -> Void in
            if error != nil {
                promise.setError(error!)
            } else {
                promise.setResult(data)
            }
        })
        
        return promise.task
    }
    
    public func respondArray(data: [AnyObject]) -> BFTask {
        var out : [BFTask] = []
        var index = 0
        for item in data {
            let i = self.respond(item)
            
            if self.batchSize > 0 && index > 0 && (index % self.batchSize) == 0  {
                i.continueWithSuccessBlock({ (task) -> AnyObject! in
                    var error: NSError?
                    self.context.performBlockAndWait { () in
                        self.context.saveToPersistentStore(&error)
                    }
                    if error != nil {
                        return BFTask(error:error!)
                    }
                    return task
                })
            }
            index++
            out.append(i)
        }
        
        return BFTask(forCompletionOfAllTasksWithResults: out).continueWithSuccessBlock({ (task) -> AnyObject! in
            var error: NSError?
            self.context.performBlockAndWait({ () -> Void in
                self.context.saveToPersistentStore(&error)
            })
            
            
            if error != nil {
                return BFTask(error: error!)
            }
            return task
        })
    }
    
    public func mapValue(value: JSON, complete:(error: NSError?, value: AnyObject?) -> Void) {
        if self.mapper != nil {
            
            self.context.performBlock {
                self.mapper!(context: self.context, value: value, complete: {(error, var result) in
                    
                    if let object = result as? NSManagedObject {
                        result = object.objectID
                    }
                
                    if let task = result as? BFTask {
                        task.continueWithBlock { (t) in
                            complete(error: t.error, value: t.result)
                            return nil
                        }
                    } else {
                        complete(error: error, value: result)
                    }
                })
            }
        } else {
            complete(error: nil, value: value.dictionaryObject)
        }
    }
    
}

