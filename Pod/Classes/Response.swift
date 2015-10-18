


import Foundation

public protocol ResponseDescriptor {
    typealias ReturnType: AnyObject
    func respond(data:AnyObject!) throws -> ReturnType?
    func respondArray(data:[AnyObject]) throws -> [ReturnType]
}


public class ResponseDescription<T: AnyObject> : ResponseDescriptor {
    public var mapper: ((value: AnyObject!) throws -> T?)?
    public init (map: (value: AnyObject!) throws -> T?) {
        self.mapper = map
    }
  
    public init () { }
  
    public func respond(data: AnyObject!) throws -> T? {
        let result = try self.mapValue(data)
        return result
  }
  
    public func respondArray(data: [AnyObject]) throws -> [T] {
    var out : [T] = []
        
    for item in data {
    
        let o = try self.respond(item)
        
        if o != nil {
            out.append(o!)
        }
        
    }
    
    return out
  }
  
    public func mapValue(value: AnyObject!) throws -> T? {
    if self.mapper != nil {
        return try self.mapper!(value: value)
    } else {
      return value as? T
    }
    
  }
}