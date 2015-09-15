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




@objc public class Resource : BaseResource {
            
        
    
    public override func request(request: NSURLRequest, progress: ProgressBlock?, completion:((req:NSURLRequest, res:NSURLResponse?, data:NSData?, error:NSError?) -> Void)? = nil)-> BFTask {
        
     
        if !should_update() {
            Restler.log.debug("\(self.name): only \(self.get_diff()) since last update. interval is: \(self.timeout)")
            return BFTask(result: nil)
        }
        
        self.lastUpdate = NSDate()
        
        self.emit(ResourceEvent.BeforeRequest, data: request)
        
        return super.request(request, progress: progress, completion:completion)
        
    }
    
}




