//
//  Request.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 04/09/15.
//
//

import Foundation
import Bolts

public protocol IRequest {
    
}

public struct RestRequest {
    let restler: Restler
    public var path: String
    public var baseURL: String
    
    
    func request (request: NSURLRequest, progress: ProgressBlock?) -> BFTask {
        let task = self.restler.request(request, progress: progress)
        
        return task.continueWithBlock { (result) -> AnyObject! in
            
            if result.error != nil {
                //self.emit(ResourceEvent.Error, data: result.error)
                return result
            }
            
            let executor = BFExecutor.mainThreadExecutor()
            
            let task: BFTask
            if self.descriptor != nil {
                if let array = result.result as? [AnyObject] {
                    task = self.descriptor!.respondArray(array)
                } else {
                    task = self.descriptor!.respond(result.result)
                }
            } else {
                task = result
            }
            
            return task.continueWithExecutor(executor, block: { (t) -> AnyObject! in
                if t.error != nil {
                    self.emit(ResourceEvent.Error, data: result.error)
                } else {
                    self.emit(ResourceEvent.Request, data: t.result)
                }
                return t
                }, cancellationToken: nil)
        }
    }
}