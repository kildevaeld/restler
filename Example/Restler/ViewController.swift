//
//  ViewController.swift
//  Restler
//
//  Created by Softshag & Me on 06/25/2015.
//  Copyright (c) 06/25/2015 Softshag & Me. All rights reserved.
//

import UIKit
import Restler
//import Alamofire
import Bolts
import DStack
import SwiftyJSON

import CoreFoundation

class ParkBenchTimer {
    
    let startTime:CFAbsoluteTime
    var endTime:CFAbsoluteTime?
    
    init() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func stop() -> CFAbsoluteTime {
        endTime = CFAbsoluteTimeGetCurrent()
        
        return duration!
    }
    
    var duration:CFAbsoluteTime? {
        if let endTime = endTime {
            return endTime - startTime
        } else {
            return nil
        }
    }
}


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = NSURL(string:"http://api.livejazz.dk")
        let restler = Restler(url:url!)
        //restler.baseURL =
        let dstack = DStack.with("test_db.sqlite")!
        
        
        
        let descriptor = EntityDescriptor(dstack.rootContext, map: { (context, value) -> AnyObject? in
            
            
            
            if value["id"] == nil {
                return nil
            }
            let concert: Concert = context.insertEntity()
            
            concert.id = value["id"].intValue
            concert.title = value["name"].stringValue
            concert.desc = value["description"].string
            
            concert.start = value["start"].doubleValue.asDate
            concert.finish = value["finish"].doubleValue.asDate
            concert.website = value["webiste"].string
            
            return concert
            
        })
        
        let genreDescriptor = EntityDescriptor(dstack.rootContext, map:{ (context, value) -> AnyObject? in
            
            if value["id"] == nil {
                return nil
            }
            
            let genre: Genre = context.insertEntity()
            genre.name = value["name"].stringValue
            genre.desc = value["description"].stringValue
            genre.id = value["id"].intValue
            
            return genre
        })
        
        let header = { (request: NSMutableURLRequest, parameters: Parameters) -> Parameters? in
            request.setValue("access-key", forHTTPHeaderField: "X-Access-Key")
            return parameters
        }
        
        let resource = restler.resource("/v2/concert", name:"concerts", descriptor: descriptor, paginated:true)
        
        resource.setOnRequest(header)
        //resource.setOnRequest(header)
        //resource.paginated = false
        //resource.timeout = 10
        
        //.paginated = true
        //restler.resource("/genre", name:"genres", descriptor: genreDescriptor)
            //.setOnRequest(header)
        
        var tasks : [BFTask] = []
        let timer = ParkBenchTimer()
        var t = restler.get(resource:"concerts", progress:nil) { (e,r,rs) in
            print("concerts complete");
        }
        tasks.append(t)
        t = restler.get(resource:"genres") { (e,r,rs) in
            print("genres complete");
        }
        tasks.append(t)
        
        BFTask(forCompletionOfAllTasks: tasks)
        .continueWithBlock { (task) -> AnyObject! in
            print("all done \(timer.stop())")
            return nil
        }
        
        
        
        /*dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            println("get \(NSThread.isMainThread())")
            restler.get(resource:"concerts", progress: { (progress,written) in
                println("\(progress)/\(written)")
                println("progress \(NSThread.isMainThread())")
                }) { (error, result, resource) -> Void in
                    println("complete \(result)")
                    //println("Every thing \(result)")
            }
            
        })*/
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

