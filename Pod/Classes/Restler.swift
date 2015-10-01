//
//  Restler.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 25/06/15.
//
//

import Foundation
import Alamofire
import ReachabilitySwift
import Promissum
import XCGLogger

let sessionIdentifier = "com.softshag.restler"
var kRestlerMappingQueue = "com.softshag.restler.mapping_queue"


public typealias ProgressBlock = (progress: Int64, total: Int64) -> Void
public typealias CompletionBlock = (error: NSError?, data: AnyObject?, resource: IResource) -> Void

public typealias serializer = (data:NSData) throws -> AnyObject


/*struct Listener : Equatable {
    var observer: AnyObject
    var event: String
    var resource: IResource?
    var handler: IEventHandler
}

func ==(lhs: Listener, rhs: Listener) -> Bool {
    return lhs.observer === rhs.observer && lhs.event == rhs.event && lhs.resource?.name == rhs.resource?.name
}


public enum Events : EventConvertible {
    case BeforeRequest (String?)
    case Request (String?)
    case BeforePaginatedRequest (String?)
    case PaginatedRequest (String?)
    case RequestPage (String?)
    
    public var eventName : String {
        let event : ResourceEvent
        var resource: String?
        
        switch self {
        case .BeforeRequest(let res):
            event = .BeforeRequest
            resource = res
        case .Request(let res):
            event = .Request
            resource = res
        case .BeforePaginatedRequest(let res):
            event = .BeforePaginatedRequest
            resource = res
        case .PaginatedRequest(let res):
            event = .PaginatedRequest
            resource = res
        case .RequestPage(let res):
            event = .RequestPage
            resource = res
        }
        
        let ev = resource == nil ? event.eventName : resource! + ":" + event.eventName
        
        return ev
    }
    
    var resourceName: String? {
        var resource: String?
        
        switch self {
        case .BeforeRequest(let res):
            resource = res
        case .Request(let res):
            resource = res
        case .BeforePaginatedRequest(let res):
            resource = res
        case .PaginatedRequest(let res):
            resource = res
        case .RequestPage(let res):
            resource = res
        }
        
        return resource
    }
}*/

public enum RestError : ErrorType {
    case Error(String)
    case HostUnreachable
}

public class Restler : NSObject {
    
    public static var serializers: Dictionary<String, serializer> = [
        "application/json": { (data) throws ->  AnyObject in
            let JSON = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            return JSON
        }]
        //"application/plist": {Alamofire.Request.propertyListResponseSerializer().serializeResponse }]
    static var log: XCGLogger {
        let log = XCGLogger()
        
        log.setup(.Debug, showThreadName: false, showLogLevel: true, showFileNames: false, showLineNumbers: false, writeToFile: nil, fileLogLevel: nil)
        
        return log
    }
    
    private let manager: Alamofire.Manager
    private let mapping_queue : dispatch_queue_t = dispatch_queue_create(kRestlerMappingQueue, DISPATCH_QUEUE_CONCURRENT)
    
    var resources : [IResource] = []
    var reachability: Reachability
    
    private var _reachabilityCheck: Bool = false
    private var _lock: NSObject = NSObject()
    private var _listeners: [PromiseSource<Bool, ErrorType>] = []
    private var reachabilityCheck: Bool {
        get {
            return synchronized(self._lock) { [unowned self] () -> Bool in
                return self._reachabilityCheck
            }
        }
        set (value) {
            synchronized(self._lock) { [unowned self] () -> Void in
                self._reachabilityCheck = value
            }
        }
        
    }
    
    public var baseURL: NSURL
    
    public init (url:NSURL) {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(sessionIdentifier)
        configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
        
        self.manager = Alamofire.Manager(configuration: configuration)
        
        self.baseURL = url
        self.reachability = Reachability(hostname: url.host!)!
    }
    
    func request(URLRequest: NSURLRequest, progress: ProgressBlock?, completion:(req:NSURLRequest?, res:NSHTTPURLResponse?, data:AnyObject?, error:ErrorType?) -> Void) {
        
        self.manager.request(.GET, URLRequest, headers:URLRequest.allHTTPHeaderFields)
            .validate()
            .progress { (written, totalWritten, totalExpected) -> Void in
                if progress != nil {
                    dispatch_main {
                        progress!(progress: totalWritten, total: totalExpected)
                    }
                }
            }
            
            .response(queue: self.mapping_queue, responseSerializer: Request.dataResponseSerializer()) { (req, res, result) -> Void in
                var error: ErrorType? = nil
                var out: AnyObject? = nil
                
                if result.isFailure {
                    error = result.error
                } else if res?.MIMEType == nil {
                    out = result.value
                } else {
                    let serializer = Restler.serializers[res!.MIMEType!]
                    
                    if serializer == nil || result.value == nil {
                        out = result.value
                        
                    } else {
                        do {
                            let result = try serializer!(data: result.value!)
                            out = result
                        } catch let e as NSError {
                            error = e
                        }
                    }
                }
                
                completion(req: req,res: res,data: out,error: error)
        }
        
        
        
    }
    
    func isReachable () -> Promise<Bool, ErrorType> {
        let source = PromiseSource<Bool, ErrorType>()
        _listeners.append(source)
        
        if self.reachabilityCheck {
            return source.promise
        }
        
        self.reachabilityCheck = true
        
        let checker = { [unowned self] (r:Reachability) in
            self.reachability.stopNotifier()
            let listeners = self._listeners
            self._listeners = []
            self.reachabilityCheck = false
            
            
            
            for s in listeners {
                s.resolve(r.isReachable())
            }
        }
        if self.reachability.whenReachable == nil {
            self.reachability.whenReachable = checker
            self.reachability.whenUnreachable = checker
        }
        
        
        self.reachability.startNotifier()
        
        return source.promise
        
    }
    
    private func findResource(name:String) -> IResource? {
        for res in self.resources {
            if res.name == name {
                return res
            }
        }
        return nil
    }
    
    
    
    public func resource<T : ResponseDescriptor>(path: String, var name: String? = nil, descriptor: T? = nil) -> Resource<T>? {
        if name == nil {
            name = path
        }
        
        var resource = findResource(name!) as? Resource<T>
        
        if resource != nil || descriptor == nil {
            return resource
        }
        
        resource = Resource(restler: self, name: name!,path: path, descriptor: descriptor!)
    
        self.resources.append(resource!)
        
        return resource!
    }
    
    }


// MARK: - Convience
extension Restler {
    
    public func fetch(name: String, params:Parameters? = nil, progress: ProgressBlock? = nil) -> Promise<[AnyObject], ErrorType> {
        let resource = findResource(name)
        if resource == nil {
            return Promise(error: RestError.Error("resource: \(name) not defined"))
        }
        
        let source = PromiseSource<[AnyObject], ErrorType>()
        resource!.request(params, completion: { (result, error) -> Void in
            if error != nil {
                source.reject(error!)
            } else {
                source.resolve(result!)
            }
        })
        
        return source.promise

    }
    
    public func fetch(resources: [String], progress: ProgressBlock? = nil) -> Promise<[[AnyObject]], ErrorType> {
        var tasks : [Promise<[AnyObject], ErrorType>] = []
        
        for name in resources {
            let task = self.fetch(name, params: nil, progress: progress)
            tasks.append(task)
        }
        
        return whenAll(tasks)
    }
}
