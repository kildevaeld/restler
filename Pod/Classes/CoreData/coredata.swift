//
//  coredata.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 10/07/15.
//
//

import Foundation
import CoreData
import DStack
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

public enum RestlerError : ErrorType {
    case Cast
    case Error(String)
}


public typealias ManagedResourceCompletetion = (context: NSManagedObjectContext, value: JSON) throws -> AnyObject?

public class EntityDescriptor<T: AnyObject> : ResponseDescriptor {
    private let mapper: ((context: NSManagedObjectContext, value: JSON) throws -> T?)?
    
    public let context: NSManagedObjectContext
    public var batchSize = 500
    public init (context: NSManagedObjectContext) {
        self.context = context
        self.mapper = nil
    }
    
    public init(_ context: NSManagedObjectContext, map: (context: NSManagedObjectContext, value: JSON) throws -> T?) {
        self.context = context
        self.mapper = map
    }
    
    public func respond(data: AnyObject!) throws -> T? {
        
        let dict = data as? NSDictionary
        
        if dict == nil {
            Restler.log.debug("could not cast data to dictionary")
            throw RestlerError.Cast
        }
        
        let json : JSON = JSON(dict!)

        
        let result = try self.mapValue(json)
        
        return result
    }
    
    public func respondArray(data: [AnyObject]) throws -> [T] {
        var out : [T] = []
        var index = 0
        //var localError: NSError?
        for item in data {
            
            //localError = nil
            
            
            let o = try self.respond(item)
            
            
            
            if self.batchSize > 0 && index > 0 && (index % self.batchSize) == 0  {
                
                self.context.performBlockAndWait { () in
                    do {
                        try self.context.save()
                    } catch { }
                }
            
            }
            index++
            if o != nil {
                 out.append(o!)
            }
           
        }
        
        self.context.performBlockAndWait({ () ->  Void in
            do {
                try self.context.saveToPersistentStore()
            } catch { }
        })
        
        
        return out
    }
    
    public func mapValue(value: JSON) throws -> T? {
        if self.mapper != nil {
            
            var localError: NSError?
            var result: T?
            
            self.context.performBlockAndWait({ () -> Void in
                do {
                    result = try self.mapper!(context:self.context, value: value)
                } catch let e as NSError {
                    localError = e
                }
                
            })
            
            if localError != nil {
                throw localError!
            }
            
            return result
            
        } else {
            return nil
        }
    }
    
}

