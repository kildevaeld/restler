


import Foundation
import Bolts

public protocol ResponseDescriptor {
    func respond(data:AnyObject!, error:NSErrorPointer?) -> AnyObject?
    func respondArray(data:[AnyObject], error:NSErrorPointer?) -> [AnyObject]
}

public typealias MapperFunc = (value: AnyObject!, error:NSErrorPointer?) -> AnyObject?

public class ResponseDescription : ResponseDescriptor {
  public var mapper: MapperFunc?
  public init (map: MapperFunc) {
    self.mapper = map
  }
  
  public init () { }
  
    public func respond(data: AnyObject!, error:NSErrorPointer?) -> AnyObject? {
        
        let result: AnyObject? = self.mapValue(data, error:error)
        return result
  }
  
    public func respondArray(data: [AnyObject], error:NSErrorPointer?) -> [AnyObject] {
    var out : [AnyObject] = []
        var localError: NSError?
    for item in data {
        localError = nil
        let o: AnyObject? = self.respond(item, error:&localError)
        
        if localError != nil {
            if error != nil {
                error!.memory = localError
            }
            return []
        }
        
        if o != nil {
            out.append(o!)
        }
        
    }
    
    return out
  }
  
    public func mapValue(value: AnyObject!, error:NSErrorPointer?) -> AnyObject? {
    if self.mapper != nil {
        return self.mapper!(value: value, error:error)
    } else {
      return value
    }
    
  }
}