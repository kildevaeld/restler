


import Foundation
import Bolts

public protocol ResponseDescriptor {
    func respond(data:AnyObject!) throws -> AnyObject?
    func respondArray(data:[AnyObject]) throws -> [AnyObject]
}

public typealias MapperFunc = (value: AnyObject!) throws -> AnyObject?

public class ResponseDescription : ResponseDescriptor {
  public var mapper: MapperFunc?
  public init (map: MapperFunc) {
    self.mapper = map
  }
  
  public init () { }
  
    public func respond(data: AnyObject!) throws -> AnyObject? {
        
        let result: AnyObject? = try self.mapValue(data)
        return result
  }
  
    public func respondArray(data: [AnyObject]) throws -> [AnyObject] {
    var out : [AnyObject] = []
        
    for item in data {
    
        let o: AnyObject? = try self.respond(item)
        
        if o != nil {
            out.append(o!)
        }
        
    }
    
    return out
  }
  
    public func mapValue(value: AnyObject!) throws -> AnyObject? {
    if self.mapper != nil {
        return try self.mapper!(value: value)
    } else {
      return value
    }
    
  }
}