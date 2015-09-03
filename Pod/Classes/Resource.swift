//
//  Resource.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/07/15.
//
//

import Foundation
import Bolts
import Alamofire


public typealias Parameters = Dictionary<String, AnyObject>

public typealias ResourceCompletion = (error:NSError?, result: AnyObject?) -> Void


func extendParameters (inout param: Parameters, param2: Parameters) {
    for (key, value) in param2 {
        param.updateValue(value, forKey: key)
    }
}


public let kBeforeRequestEvent = "before:request"
public let kRequestEvent = "request"
public let kBeforeRequestPaginatedEvent = "before:request:paginated"
public let kRequestPage = "request:page"
public let kRequestPaginated = "request:paginated"
public let kErrorEvent = "error"

public enum ResourceEvent : String, EventConvertible {
    case BeforeRequest = "before:request"
    case Request = "request"
    case BeforePaginatedRequest = "before:request:paginated"
    case RequestPage = "request:page"
    case PaginatedRequest = "request:paginated"
    case Error = "error"
    
    public var eventName: String {
        return self.rawValue
    }
}
func synchronized (obj:NSObject, fn:() -> Void) {
    objc_sync_enter(obj)
    fn()
    objc_sync_exit(obj)
}

func synchronized<T>(obj:NSObject, fn:() -> T) -> T {
    let result: T
    objc_sync_enter(obj)
    result = fn()
    objc_sync_exit(obj)
    return result
}


@objc public class Resource : EventEmitter, Equatable {
    private var _lock = NSObject()
    private var _lastUpdate: NSDate?
    private var lastUpdate: NSDate? {
        get {
            return synchronized(_lock) {
                return self._lastUpdate
            }
        } set (value) {
            synchronized(_lock) {
                self._lastUpdate = value
            }
        }
    }
    
    
    private let restler: Restler
    
    private let pagination_queue = dispatch_queue_create("pagination_queue", DISPATCH_QUEUE_SERIAL)
    
    public let path: String
    public var name: String
    public var parameters: Parameters?
    public var descriptor: ResponseDescriptor?
    
    public var timeout: Double = 0
    public var paginated: Bool = false
    
    private var _baseURL: NSURL?
    public var baseURL: NSURL {
    get {
        if _baseURL == nil {
            _baseURL = self.restler.baseURL
        }
        return _baseURL!
    }
    set (url) {
        _baseURL = url
    }
    }
    public var onRequestBlock: ((request: NSMutableURLRequest, parameters: Parameters) -> Parameters?)?
    
    public func setOnRequest (fn: (request: NSMutableURLRequest, parameters: Parameters) -> Parameters?) -> Self {
        self.onRequestBlock = fn
        return self
    }
    
    public var onPaginateBlock: ((parameters: Parameters, page: Int) -> Parameters)?
    
    public func setOnPaginate (fn: (parameters: Parameters, page: Int) -> Parameters) -> Self {
        self.onPaginateBlock = fn
        return self
    }
    
    init (restler: Restler, path: String, name: String) {
        self.path = path
        self.name = name
        self.restler = restler
    }
    
    
    public func request (request: NSURLRequest, progress: ProgressBlock?) -> BFTask {
        
        let now = NSDate()
        
        let diff = self.lastUpdate != nil ? now.timeIntervalSinceNow - self.lastUpdate!.timeIntervalSinceNow : self.timeout
        let to = self.timeout
        if diff < self.timeout {
            Restler.log.debug("\(self.name): only \(diff) since last update. interval is: \(self.timeout)")
            return BFTask(result: nil)
        }
        
        self.lastUpdate = now
        
        self.emit(ResourceEvent.BeforeRequest, data: request)
        
        let task = self.restler.request(request, progress: progress)
        
        return task.continueWithBlock { (result) -> AnyObject! in
            
            if result.error != nil {
                self.emit(ResourceEvent.Error, data: result.error)
                return task
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
    
    public func request (path: String, parameters: Parameters?, method: Alamofire.Method = .GET, progress: ProgressBlock? = nil) -> BFTask {
        
        let (error, request, params) = self.getRequest(method: method, path: path, parameters: parameters)
        
        
        
        if error != nil {
            self.emit(ResourceEvent.Error, data: error)
            return BFTask(error: error)
        }
        return self.request(request, progress: progress)
        
    }
    
    public func requestPaginated (path: String, parameters: Parameters?, key: String = "page") -> BFTask {
        return self.requestPaginated(path, parameters: parameters, paginate: { (var param, page) -> Parameters in
            param.updateValue(page,forKey:key)
            return param
        })
    }
    
    public func requestPaginated (path: String, parameters: Parameters?, paginate: (parameters: Parameters, page: Int) -> Parameters) -> BFTask {
        
        let promise = BFTaskCompletionSource()
        
        self.emit("before:request:paginated")
        
        dispatch_async(self.pagination_queue, { () -> Void in
            var params = Parameters()
            
            if parameters != nil {
                params = parameters!
            }
            var currentPage = 0
            var results : [AnyObject] = []
            
            
            
            while true {
                
                params = paginate(parameters: params, page: currentPage++)
                
                let t = self.request(path, parameters: params, method: .GET, progress: nil)
                t.waitUntilFinished()
                
                if t.error != nil {
                    promise.setError(t.error!)
                    return
                }
                
                self.emit("request:page", data: ["page":currentPage, "data":results])
                
                if t.result === nil {
                    break
                } else if let array = t.result as? [AnyObject] {
                    if array.isEmpty {
                        break
                    }
                } else if let p = t.result as? Parameters {
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
    
    
    private func getRequest (method: Alamofire.Method = .GET, path: String, parameters: Parameters?) -> (error: NSError?, request: NSURLRequest, parameters: Parameters) {
        
        let url = self.baseURL.URLByAppendingPathComponent(path)
        var request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method.rawValue
        
        var params = Parameters()
        
        if self.parameters != nil {
            params = self.parameters!
        }
        
        if parameters != nil {
            extendParameters(&params, parameters!)
        }
        
        if self.onRequestBlock != nil {
            let p = self.onRequestBlock!(request: request, parameters: params)
            if p != nil {
                params = p!
            }
        }
        
        if !params.isEmpty {
            let encoded = self.encodeRequest(request, parameters: params)
            
            if encoded.error != nil {
                return (encoded.error, request, params)
            }
            request = encoded.request?.mutableCopy() as! NSMutableURLRequest
        }
        
        
        return (nil, request, params)
    }
    
    func encodeRequest (request: NSURLRequest, parameters: Parameters) -> (error: NSError?, request: NSURLRequest?) {
        let encoding = Alamofire.ParameterEncoding.URL
        let encoded = encoding.encode(request, parameters: parameters)
        if encoded.1 != nil {
            return (encoded.1, nil)
        }
        
        let request = encoded.0 as NSURLRequest
        
        return (nil, request)
    }
    
}

public func ==(lhs: Resource, rhs: Resource) -> Bool {
    return lhs.name == rhs.name
}


extension Resource {
    
    
    public func all<T>(parameters:Parameters? = nil, complete:(error: NSError?, result:[T]?) -> Void) -> BFTask {
        return self.all(parameters) { (error, result) -> Void in
            complete(error: error, result: result as? [T])
        }
    }
    
    public func all(parameters:Parameters?, progress:ProgressBlock? = nil, complete: ResourceCompletion?) -> BFTask {
        let task: BFTask
        
        if self.paginated {
            if self.onPaginateBlock != nil {
                task = self.requestPaginated(self.path, parameters: parameters, paginate: self.onPaginateBlock!)
            } else {
                task = self.requestPaginated(self.path, parameters: parameters)
            }
        } else {
            task = self.request(self.path, parameters: parameters, progress:progress)
        }
        
        return task.continueWithBlock { (task) -> AnyObject! in
            complete?(error: task.error, result: task.result)
            return task.result
        }
    }
    
    public func get(id: String, complete: ResourceCompletion) {
        let path = self.path.stringByAppendingPathComponent(id)
        self.request(path, parameters: nil)
            .continueWithBlock { (task) -> AnyObject! in
                complete(error: task.error, result: task.result)
                return nil
        }
    }
    
    public func get<T>(id: String, complete: (error: NSError?, result: T?) -> Void) {
        self.get(id, complete: { (error, result) -> Void in
            complete(error: error, result: result as? T)
        })
    }
    
}

