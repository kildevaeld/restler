//
//  Resource.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/07/15.
//
//

import Foundation
import Alamofire




public class Resource<T:ResponseDescriptor> : BaseResource<T> {
    private var _paginate: Bool = false
    
    
    
    var pagination_queue = dispatch_queue_create("com.softshag.restler.pagination", DISPATCH_QUEUE_SERIAL)
    
    public var onPaginateBlock: ((parameters: Parameters, page: Int) -> Parameters)?
    
    public func setOnPaginate (fn: (parameters: Parameters, page: Int) -> Parameters) -> Self {
        self.onPaginateBlock = fn
        return self
    }
    
    public func paginate () -> Self {
        _paginate = !_paginate
        return self
    }
    
    override init(restler: Restler, name: String, path: String, descriptor:T) {
        super.init(restler: restler, name: name, path: path, descriptor: descriptor)
    }

    override func request(request: NSURLRequest, progress: ProgressBlock?, completion:(data:[T.ReturnType]?, error:ErrorType?) -> Void) {
        if !should_update() {
            Restler.log.debug("\(self.name): only \(self.get_diff()) since last update. interval is: \(self.timeout)")
            completion(data: nil, error: nil)
        }
        
        self.lastUpdate = NSDate()
        
        if _paginate == false {
            super.request(request, progress: progress, completion: completion)
            return
        }
        var params = Parameters()
        
        if parameters != nil {
            params = parameters!
        }
        var currentPage = 0
        var results : [T.ReturnType] = []
        
        
        
        func next (var page: Int) {
            self.requestPage(page, request: request, parameters: params, progress: progress, completion: { (data, error) -> Void in
                
                if error != nil || data == nil {
                    completion(data:results , error: error)
                    return 
                }
                results += data!
                next(++page)
            })
        }
        
        next(0)
        
        
        
    }
    
    // MARK: - Pagination
    private func requestPage(page:Int, request:NSURLRequest, parameters:Parameters, progress:ProgressBlock?, completion:(data:[T.ReturnType]?, error:ErrorType?) -> Void)   {
        
        let req = getPaginateParameters(request, parameters: parameters, page: page)
        
        if (req == nil) {
            return completion(data: nil, error: NSError(domain: "com.softshag.restler", code: 1, userInfo: nil))
        }
        
        return super.request(req!, progress: progress, completion:completion)
        
    }
    
    private func getPaginateParameters(request: NSURLRequest, parameters:Parameters, page:Int) -> NSURLRequest? {
        
        var params: Parameters = parameters
        if (self.onPaginateBlock != nil) {
            params = self.onPaginateBlock!(parameters: parameters, page: page);
        } else {
            params["page"] = String(page)
        }
        do {
            let eReq = try self.encodeRequest(request, parameters: params)
            return eReq.mutableCopy() as! NSMutableURLRequest
        } catch {
            return nil
        }
        
        
    }
}




