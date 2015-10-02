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
import Promissum


extension NSManagedObjectContext {
    public func performBlockPromise(block: PerformBlock) -> Promise<CommitAction, DStackError> {
        let promiseSource = PromiseSource<CommitAction, DStackError>()
        
        performBlock(block) { result in
            dispatch_async(dispatch_get_main_queue()) {
                do {
                    let action = try result()
                    promiseSource.resolve(action)
                }
                catch let error as DStackError {
                    promiseSource.reject(error)
                }
                catch let error {
                    promiseSource.reject(DStackError.Error(error))
                }
            }
        }
        
        return promiseSource.promise
    }
}

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

public class EntityDescriptor<T: NSManagedObject> : ResponseDescriptor {
    private let mapper: ((context: NSManagedObjectContext, value: JSON) throws -> T?)?
    
    public let dstack: DStack
    public var batchSize = 500
    public init (dstack: DStack) {
        self.dstack = dstack
        self.mapper = nil
    }
    
    public init(_ dstack: DStack, map: (context: NSManagedObjectContext, value: JSON) throws -> T?) {
        self.dstack = dstack
        self.mapper = map
    }
    
    public func respond(data: AnyObject!) throws -> T? {
        
        let dict = data as? NSDictionary
        
        if dict == nil {
            Restler.log.debug("could not cast data to dictionary")
            throw RestlerError.Cast
        }
        
        let json : JSON = JSON(dict!)

        
        let objectId = try self.mapValue(json)
        
        if objectId == nil {
            return nil
        }
        
        var result: T?
        
        self.dstack.mainContext.performBlockAndWait { [unowned self] () -> Void in
            result = self.dstack.mainContext.objectRegisteredForID(objectId!) as? T
        }
        
        return result
    }
    
    public func respondArray(data: [AnyObject]) throws -> [T] {
        var out : [T] = []
        var index = 0
        var item: T?
        //var localError: NSError?
        for i in data {
            
            //localError = nil
            
            do {
                item = try self.respond(i)
            } catch let e {
                Restler.log.error("\(e)")
                continue
            }
            
            
            
            
            /*if self.batchSize > 0 && index > 0 && (index % self.batchSize) == 0  {
                
                /*self.context.performBlockAndWait { () in
                    do {
                        try self.context.save()
                    } catch { }
                }*/
                
            
            }*/
            index++
            if item != nil {
                 out.append(item!)
            }
           
        }
        
        /*self.context.performBlockAndWait({ () ->  Void in
            do {
                try self.context.saveToPersistentStore()
            } catch { }
        })*/
        
        
        return out
    }
    
    public func mapValue(value: JSON) throws -> NSManagedObjectID? {
        if self.mapper != nil {
            let context = self.dstack.workerContext
            var result: T?
            var error: ErrorType?
            context.performBlockAndWait { [unowned self] in
                do {
                    
                    result = try self.mapper!(context:context, value:value)
                    
                    if result != nil {
                        try context.saveToPersistentStoreAndWait()
                    }
                    
                } catch let e {
                    error = e
                }
            }
            
            if error != nil {
                throw error!
            }
            
            return result == nil ? nil : result!.objectID
            
        } else {
            return nil
        }
    }
    
}

