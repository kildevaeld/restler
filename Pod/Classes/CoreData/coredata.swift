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


public typealias ManagedResourceCompletetion = (context: NSManagedObjectContext, value: JSON, error:NSErrorPointer?) -> AnyObject?

public class EntityDescriptor : ResponseDescriptor {
    private let mapper: ManagedResourceCompletetion?
    
    public let context: NSManagedObjectContext
    public var batchSize = 500
    public init (context: NSManagedObjectContext) {
        self.context = context
        self.mapper = nil
    }
    
    public init(_ context: NSManagedObjectContext, map: ManagedResourceCompletetion) {
        self.context = context
        self.mapper = map
    }
    
    public func respond(data: AnyObject!, error:NSErrorPointer?) -> AnyObject? {
        
        let dict = data as? NSDictionary
        
        if dict == nil {
            Restler.log.debug("could not cast data to dictionary")
            error?.memory = NSError()
            return nil
        }
        
        let json : JSON = JSON(dict!)

        
        let result: AnyObject? = self.mapValue(json, error: error)
        
        
        return result
    }
    
    public func respondArray(data: [AnyObject], error:NSErrorPointer?) -> [AnyObject] {
        var out : [AnyObject] = []
        var index = 0
        var localError: NSError?
        for item in data {
            
            localError = nil
            
            let o: AnyObject? = self.respond(item, error:&localError)
            
            if localError != nil {
                if error != nil {
                    error?.memory = localError
                }
                return []
            }
            
            if self.batchSize > 0 && index > 0 && (index % self.batchSize) == 0  {
                
                /*self.context.performBlockAndWait { () in
                    self.context.save(&localError)
                }*/
                
                if localError != nil {
                    if error != nil {
                        error?.memory = localError
                    }
                    
                    return []
                }
                
            }
            index++
            if o != nil {
                 out.append(o!)
            }
           
        }
    
        self.context.performBlockAndWait({ () -> Void in
            self.context.save(&localError)
        })
        
        if localError != nil {
            error?.memory = localError
            return out
        }
        return out
    }
    
    public func mapValue(value: JSON, error:NSErrorPointer?) -> AnyObject? {
        if self.mapper != nil {
            
            var localError: NSError?
            var result: AnyObject?
            
            self.context.performBlockAndWait({ () -> Void in
                result = self.mapper!(context:self.context, value: value, error:&localError)
            })
            
            
            if localError != nil {
                if error != nil {
                    error?.memory = localError
                }
                return nil
            }
            
            return result
            
        } else {
            return value.dictionaryObject
        }
    }
    
}

