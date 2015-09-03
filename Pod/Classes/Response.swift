


import Foundation
import Bolts

public protocol ResponseDescriptor {
    func respond(data:AnyObject) -> BFTask
    func respondArray(data:[AnyObject]) -> BFTask
}

public typealias MapperFunc = (value: AnyObject!, complete: ResourceCompletion) -> Void

public class ResponseDescription : ResponseDescriptor {
  public var mapper: MapperFunc?
  public init (map: MapperFunc) {
    self.mapper = map
  }
  
  public init () { }
  
  public func respond(data: AnyObject) -> BFTask {
    let task = BFTaskCompletionSource()
    
    self.mapValue(data, complete: { (error, data) -> Void in
      if error != nil {
        task.setError(error!)
      } else {
        task.setResult(data)
      }
    })
    
    return task.task
  }
  
  public func respondArray(data: [AnyObject]) -> BFTask {
    var out : [BFTask] = []
    for item in data {
      let i = self.respond(item)
      out.append(i)
    }
    
    return BFTask(forCompletionOfAllTasksWithResults: out)
  }
  
  public func mapValue(value: AnyObject, complete: (error: NSError?, data: AnyObject?) -> Void) {
    if self.mapper != nil {
      self.mapper!(value: value, complete: complete)
    } else {
      complete(error: nil, data: value)
    }
    
  }
}