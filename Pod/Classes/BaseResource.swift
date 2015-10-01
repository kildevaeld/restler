//
//  BBaseResource.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 30/09/15.
//
//

import Foundation
import Alamofire
import Promissum


public protocol IResource {
    var name: String { get }
    var timeout: Double { get set }
    func request(parameters:Parameters?, completion:(result:[AnyObject]?, error:ErrorType?) -> Void)
}

public typealias Parameters = Dictionary<String, AnyObject>

func +(var lhs:Parameters, rhs:Parameters) -> Parameters {
    for (key, value) in rhs {
        lhs.updateValue(value, forKey: key)
    }
    return lhs
}

func +=(inout lhs:Parameters, rhs:Parameters) {
    lhs = lhs + rhs
}


public class BaseResource<T:ResponseDescriptor where T.ReturnType:AnyObject> : IResource {
    // MARK: - Properties
    private let restler: Restler
    private let _lock = NSObject();
    private var _lastUpdate: NSDate?
    
    public var lastUpdate: NSDate? {
        get {
            return synchronized(_lock) { () -> NSDate? in
                return self._lastUpdate
            }
        }
        set (value) {
            synchronized(_lock) {
                self._lastUpdate = value
            }
        }
    }
    
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


    
    // Name of the resouce
    public let name: String
    // The path of the resource, relative to baseURL
    public let path: String
    // Minimum duration since last update
    public var timeout: Double = 0
    // Reponse descriptor
    public var descriptor: T
    // Parameters for all request on the resource
    public var parameters: Parameters = Parameters()
    

    init(restler: Restler, name: String, path: String, descriptor:T) {
        self.restler = restler
        self.name = name
        self.path = path
        self.descriptor = descriptor
    }
    
    
    func request(request: NSURLRequest, progress: ProgressBlock?, completion:(data:[T.ReturnType]?, error:ErrorType?) -> Void) {
    
        //self.lastUpdate = NSDate()
        
        self.restler.request(request, progress: progress) { [unowned self] (req, res, data, error) -> Void in
            
            if error != nil {
                completion(data: nil,error: error)
                return
            }
            
            do {
                let item: [T.ReturnType]?
                if let array = data as? [AnyObject] {
                    item = try self.descriptor.respondArray(array)
                } else {
                    let i = try self.descriptor.respond(data)
                    if i != nil {
                        item = [i!]
                    } else {
                        item = nil
                    }
                }
                
                completion(data: item, error: nil)
                
            } catch let e as NSError {
                completion(data: nil, error: e)
            }
        }
        
    }
    
    func request (path: String, parameters: Parameters?, method: Alamofire.Method = .GET, progress: ProgressBlock? = nil) -> Promise<[T.ReturnType]?, ErrorType> {
        
        let promiseSource = PromiseSource<[T.ReturnType]?, ErrorType>()
        
        let request: NSURLRequest
        do {
            (request,_) = try self.getRequest(method, path: path, parameters: parameters)
        } catch let e {
            promiseSource.reject(e)
            return promiseSource.promise
        }
        
        self.request(request, progress: progress) { (data, error) -> Void in
            
            if error != nil {
                promiseSource.reject(error!)
            } else {
                promiseSource.resolve(data)
            }
        }

        return promiseSource.promise
    }
    // IResource
    public func request(parameters:Parameters?, completion:(result:[AnyObject]?, error:ErrorType?) -> Void) {
        self.request(self.path, parameters: parameters)
        .then { (result: [T.ReturnType]?) -> Void in
            var res: [AnyObject]? = nil
            if result != nil {
                res = result! as [AnyObject]
            }
            completion(result: res, error: nil)
        }.trap { (error) -> Void in
            completion(result: nil, error: error)
        }
    }
    
    
    // MARK: - Internals
    private func getRequest (method: Alamofire.Method = .GET, path: String, parameters: Parameters?) throws -> (request: NSURLRequest, parameters: Parameters) {
        
        let url = self.baseURL.URLByAppendingPathComponent(path)
        var request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method.rawValue
        
        var params = self.parameters
        
        if parameters != nil {
            params += parameters!
        }
        
        if self.onRequestBlock != nil {
            let p = self.onRequestBlock!(request: request, parameters: params)
            if p != nil {
                params = p!
            }
        }
        
        if !params.isEmpty {
            request = try self.encodeRequest(request, parameters: params)
        }
        
        return (request, params)
    }
    
    func encodeRequest (request: NSURLRequest, parameters: Parameters) throws -> NSMutableURLRequest {
        let encoding = Alamofire.ParameterEncoding.URL
        let encoded = encoding.encode(request, parameters: parameters)
        if encoded.1 != nil {
            throw encoded.1!
        }
        
        return (encoded.0 as NSURLRequest).mutableCopy() as! NSMutableURLRequest
    }
    
    func should_update () -> Bool {
        let diff = self.get_diff()
        return diff >= self.timeout
    }
    
    func get_diff () -> Double {
        let now = NSDate()
        let diff = self.lastUpdate != nil ? now.timeIntervalSinceNow - self.lastUpdate!.timeIntervalSinceNow : self.timeout
        return diff
    }
}

