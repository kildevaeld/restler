//
//  Restler.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 25/06/15.
//
//

import Foundation
import Alamofire
import Bolts
import XCGLogger

let sessionIdentifier = "com.softshag.restler"
var kRestlerMappingQueue = "com.softshag.restler.mapping_queue"

func dispatch_main(fn:() -> Void) {
    dispatch_async(dispatch_get_main_queue(), fn)
}


public typealias ProgressBlock = (progress: Int64, total: Int64) -> Void
public typealias CompletionBlock = (error: NSError?, data: AnyObject?, resource: Resource) -> Void

public typealias serializer = (request: NSURLRequest, response: NSHTTPURLResponse?, data: NSData?) -> (AnyObject?, NSError?)


//func get_serializer(mime: String?) -> ResponseSerializer? {
//    if mime == nil {
//        return nil
//    }
//    switch mime! {
//    case "application/json":
//        return Alamofire.Request.JSONResponseSerializer().serializeResponse
//    case "application/plist", "application/x-plist":
//        return Alamofire.Request.propertyListResponseSerializer().serializeResponse
//    default:
//        if Restler.serializers[mime!] != nil {
//            return Restler.serializers[mime!]
//        }
//        return nil
//    }
//}

struct Listener : Equatable {
    var observer: AnyObject
    var event: String
    var resource: Resource?
    var handler: IEventHandler
}

func ==(lhs: Listener, rhs: Listener) -> Bool {
    return lhs.observer === rhs.observer && lhs.event == rhs.event && lhs.resource == rhs.resource
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
}

public class Restler : NSObject {
    public static var serializers: Dictionary<String,() -> serializer> = [
        "application/json": { Alamofire.Request.JSONResponseSerializer(options: nil).serializeResponse },
        "application/plist": {Alamofire.Request.propertyListResponseSerializer().serializeResponse }]
    static var log: XCGLogger {
        let log = XCGLogger()
        log.setup(logLevel: .Debug, showThreadName: false, showLogLevel: true, showFileNames: false, showLineNumbers: false, writeToFile: nil, fileLogLevel: nil)
        
        return log
    }
    
    let manager: Alamofire.Manager
    let mapping_queue : dispatch_queue_t = dispatch_queue_create(kRestlerMappingQueue, DISPATCH_QUEUE_CONCURRENT)
    let emitter = EventEmitter()
    
    var resources : [Resource] = []
    var listeners : [Listener] = []
    
    public var baseURL: NSURL
    
    public init (url:NSURL) {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(sessionIdentifier)
        configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
        self.manager = Alamofire.Manager(configuration: configuration)
        
        self.baseURL = url
    }
    
    func request(URLRequest: URLRequestConvertible, progress: ProgressBlock?) -> BFTask {
        
        let task = BFTaskCompletionSource()
        
        let req = self.manager.request(URLRequest)
            .validate()
            .progress { (written, totalWritten, totalExpected) -> Void in
                dispatch_main {
                    progress?(progress: totalWritten, total: totalExpected)
                }
            }
            .response(queue: self.mapping_queue, responseSerializer: Request.dataResponseSerializer()) { (req, res, data, error) in
                
                if error != nil {
                    task.setError(error)
                    return
                }
                
                if (res?.MIMEType == nil) {
                    task.setResult(data)
                    return
                }
                let serializer = Restler.serializers[res!.MIMEType!]
                
                if serializer == nil {
                    task.setResult(data)
                    return
                }
                
                let (result: AnyObject?, error) = serializer!()(request: req,response: res,data: data)
                
                if error != nil {
                    task.setError(error)
                } else {
                    task.setResult(result)
                }
                
            }
        
        return task.task
        
    }
    
    public func resource(path: String, var name: String? = nil, descriptor: ResponseDescriptor? = nil) -> Resource {
        if name == nil {
            name = path
        }
        let resource = Resource(restler:self, path: path, name: name!)
        
        if contains(self.resources, resource) {
            return self.resources[find(self.resources,resource)!]
        }
        
        resource.on("all", handler: self.onResourceEmit)
        
        resource.descriptor = descriptor
        self.resources.append(resource)
        
        return resource
    }
    
    private func onResourceEmit (event: IEvent) {
        let sender = event.sender as! Resource
        
        let ev = sender.name + ":" + event.name
        
        self.emitter.emit(ev, data: event as? AnyObject)
        self.emitter.emit(event.name, data: event as? AnyObject)
    }
    
    /*public func on<T: IEvent>(observer: AnyObject, event: String, handler: (event: T) -> Void) {
    let splitted = split(event) { $0 == ":" }
    let listener: Listener
    var resource: Resource?
    
    if splitted.count >= 2 {
    resource = self.resource(splitted[0])
    }
    
    
    let ehandler = self.emitter.on(event, handler: handler)
    
    listener = Listener(observer: observer, event: event, resource: resource, handler: ehandler)
    
    self.listeners.append(listener)
    }*/
    
    public func on(observer: AnyObject, event: Events, handler: (event: IEvent) -> Void) {
        //let splitted = split(event) { $0 == ":" }
        let listener: Listener
        var resource: Resource?
        
        if event.resourceName != nil {
            resource = self.resource(event.resourceName!)
        }
        
        
        let ehandler = self.emitter.on(event, handler: handler)
        
        listener = Listener(observer: observer, event: event.eventName, resource: resource, handler: ehandler)
        
        self.listeners.append(listener)
        
    }
    
    public func off(observer: AnyObject?, event: Events) {
        let lis = self.listeners
        
        for listener in lis {
            if listener.event == event.eventName && listener.observer === observer {
                self.emitter.off(listener.handler)
                self.listeners.removeAtIndex(find(self.listeners, listener)!)
            }
        }
    }
    
    public func off(observer: AnyObject?) {
        let lis = self.listeners
        
        for listener in lis {
            if listener.observer === observer {
                self.emitter.off(listener.handler)
                self.listeners.removeAtIndex(find(self.listeners, listener)!)
            }
        }
    }
    
    deinit {
        for resource in self.resources {
            resource.off()
        }
        self.emitter.off()
    }
}


// MARK: - Convience
extension Restler {
    
    public func get(resource name: String, params:Parameters? = nil, progress: ProgressBlock? = nil, complete: CompletionBlock? = nil) -> BFTask {
        let resource = self.resource(name)
        return resource.all(params, progress:progress, complete: { (error, result) in
            complete?(error: error,data: result,resource: resource)
        })
    }
    
    public func get(resources: [String], progress: ProgressBlock? = nil, complete:((error:NSError?) -> Void)? = nil) -> BFTask {
        var tasks : [BFTask] = []
        
        
        for name in resources {
            let task = self.get(resource: name, progress: nil, complete: { (error, data, resource) -> Void in
                
            })
            
            tasks.append(task)
        }
        
        return BFTask(forCompletionOfAllTasks: tasks)
            .continueWithBlock { (task) -> AnyObject! in
                complete?(error: task.error)
                return nil
        }
        
    }
}
