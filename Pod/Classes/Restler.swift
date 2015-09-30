//
//  Restler.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 25/06/15.
//
//

import Foundation
import Alamofire
//import Bolts
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
    
    let manager: Alamofire.Manager
    let mapping_queue : dispatch_queue_t = dispatch_queue_create(kRestlerMappingQueue, DISPATCH_QUEUE_CONCURRENT)
    let emitter = EventEmitter()
    
    var resources : [IResource] = []
    //var listeners : [Listener] = []
    
    public var baseURL: NSURL
    
    public init (url:NSURL) {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(sessionIdentifier)
        configuration.HTTPAdditionalHeaders = Alamofire.Manager.defaultHTTPHeaders
        self.manager = Alamofire.Manager(configuration: configuration)
        
        self.baseURL = url
    }
    
    func request(URLRequest: NSURLRequest, progress: ProgressBlock?, completion:(req:NSURLRequest?, res:NSHTTPURLResponse?, data:AnyObject?, error:ErrorType?) -> Void) {
        
        self.manager.request(.GET, URLRequest)
        .validate()
        
        self.manager.request(.GET, URLRequest)
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
    
    private func findResource(name:String) -> IResource? {
        for res in self.resources {
            if res.name == name {
                return res
            }
        }
        return nil
    }
    
    /*public func findResource<U>(type:U.Type) -> IResource? {
        for res in self.resources {
            if let r = res as? BaseResource<ResponseDescription<U>,U> {
                if r.descriptor.dynamicType.ReturnType.self == type {
                    return r
                }
            }
        }
        return nil
    }*/
    
    public func resource<T : ResponseDescriptor>(path: String, var name: String? = nil, descriptor: T, paginated:Bool = false) -> Resource<T> {
        if name == nil {
            name = path
        }
        
        /*let resource = Resource(restler:self, path: path, name: name!)
        
        if contains(self.resources, resource) {
            return self.resources[find(self.resources,resource)!]
        }*/
        
        var resource = findResource(name!) as? Resource<T>
        
        if resource != nil {
            return resource!
        }
        
        if paginated == true {
            //resource = PaginatedResource(restler:self, path: path, name: name!, descriptor)
        } else {
            resource = Resource(restler: self, name: name!,path: path, descriptor: descriptor)
        }
    
        //resource!.descriptor = descriptor
        self.resources.append(resource!)
        
        return resource!
    }
    
    /*private func onResourceEmit (event: IEvent) {
        let sender = event.sender as! Resource
        
        let ev = sender.name + ":" + event.name
        
        self.emitter.emit(ev, data: event as? AnyObject)
        self.emitter.emit(event.name, data: event as? AnyObject)
    }
    
    
    public func on(observer: AnyObject, event: Events, handler: (event: IEvent) -> Void) {
        
        let listener: Listener
        var resource: IResource?
        
        if event.resourceName != nil {
            resource = self.resource(event.resourceName!)
        }
        
        
        let ehandler = self.emitter.on(event, handler: handler)
        
        listener = Listener(observer: observer, event: event.eventName, resource: resource, handler: ehandler)
        
        self.listeners.append(listener)
        
    }*/
    /*
    public func off(observer: AnyObject?, event: Events) {
        let lis = self.listeners
        
        for listener in lis {
            if listener.event == event.eventName && listener.observer === observer {
                self.emitter.off(listener.handler)
                self.listeners.removeAtIndex(self.listeners.indexOf(listener)!)
            }
        }
    }
    
    public func off(observer: AnyObject?) {
        let lis = self.listeners
        
        for listener in lis {
            if listener.observer === observer {
                self.emitter.off(listener.handler)
                self.listeners.removeAtIndex(self.listeners.indexOf(listener)!)
            }
        }
    }
    
    deinit {
        for _ in self.resources {
            //resource.off()
        }
        self.emitter.off()
    }*/
}


// MARK: - Convience
/*extension Restler {
    
    public func get(resource name: String, params:Parameters? = nil, progress: ProgressBlock? = nil, complete: CompletionBlock? = nil) -> BFTask {
        let resource = self.resource(name)
        /*return resource.all(params, complete: { (error:NSError?, result:AnyObject?) -> Void in
            complete?(error: error,data: result,resource: resource)
        })*/
        return resource.all(params, progress:nil, complete: { (error, result) -> Void in
            //complete?(error: error, data: <#T##AnyObject?#>, resource: <#T##Resource#>)
        });

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
}*/
