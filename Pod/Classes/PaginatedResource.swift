//
//  PaginatedResource.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 05/09/15.
//
//

import Foundation
import Bolts
import Alamofire

@objc public class PaginatedResource : BaseResource {
    var pagination_queue = dispatch_queue_create("com.softshag.restler.pagination", DISPATCH_QUEUE_SERIAL)
    public var onPaginateBlock: ((parameters: Parameters, page: Int) -> Parameters)?
    
    public func setOnPaginate (fn: (parameters: Parameters, page: Int) -> Parameters) -> Self {
        self.onPaginateBlock = fn
        return self
    }

    
    public override func request (request: NSURLRequest, progress: ProgressBlock?, completion:((req:NSURLRequest, res:NSURLResponse?, data:NSData?, error:NSError?) -> Void)? = nil) -> BFTask {
        
        if !should_update() {
            Restler.log.debug("\(self.name): only \(self.get_diff()) since last update. interval is: \(self.timeout)")
            return BFTask(result: nil)
        }
        
        self.lastUpdate = NSDate()
        
        
        self.emit("before:request:paginated")
        
        var params = Parameters()
        
        if parameters != nil {
            params = parameters!
        }
        var currentPage = 0
        var results : [AnyObject] = []
        
        
        let promise = BFTaskCompletionSource();
        
        
        dispatch_async(self.pagination_queue, { () -> Void in
            
            while true {
                
                let t = self.requestPage(currentPage++, request: request, parameters: params, progress: progress, completion: completion)
                
                t.waitUntilFinished()
                
                if t.error != nil {
                    promise.setError(t.error!)
                    return
                }
                
                self.emit("request:page", data: ["page":currentPage - 1, "data":results])
                let result: AnyObject! = t.result
                
                if result === nil {
                    break
                } else if let array = result as? [AnyObject] {
                    if array.isEmpty {
                        break
                    }
                } else if let p = result as? Parameters {
                    if p.isEmpty {
                        break
                    }
                }
                
                results.append(t.result)
                
            }
            
            promise.setResult(results)
            
            self.emit("request:paginated", data: results)
            
        })
        
        
        return promise.task
        
    }
    
    
    private func requestPage(page:Int, request:NSURLRequest, parameters:Parameters, progress:ProgressBlock?, completion:((req:NSURLRequest, res:NSURLResponse?, data:NSData?, error:NSError?) -> Void)?) -> BFTask {
        
        let req = getPaginateParameters(request, parameters: parameters, page: page)
        
        if (req == nil) {
            return BFTask(error: NSError(domain: "com.softshag.restler", code: 1, userInfo: nil))
        }
  
        return super.request(req!, progress: progress, completion:completion)
        
    }
    
    private func getPaginateParameters(request: NSURLRequest, parameters:Parameters, page:Int) -> NSURLRequest? {
    
        var params: Parameters = parameters
        if (self.onPaginateBlock != nil) {
            params = self.onPaginateBlock!(parameters: parameters, page: page);
        } else {
            params["page"] = page
        }
        
        let encoded = self.encodeRequest(request, parameters: params)
        
        if encoded.error != nil {
            return nil
        }
        return encoded.request!.mutableCopy() as! NSMutableURLRequest
        
    }
    
    
}