//
//  File.swift
//  Pods
//
//  Created by Rasmus Kildevæld   on 09/07/15.
//
//

import Foundation
import Bolts
public protocol IEvent {
    
    weak var sender: AnyObject? { get }
    var name: String { get }
    var data: AnyObject? { get }
    init (sender: AnyObject, name: String, data: AnyObject?)
}

public class Event : IEvent {
    public weak var sender: AnyObject?
    public let name: String
    public let data: AnyObject?
    public required init(sender: AnyObject, name: String, data: AnyObject?) {
        self.sender = sender
        self.name = name
        self.data = data
    }
}

public class TEvent<T>: Event {
    public func data () -> T? {
        return self.data as? T
    }
    
    public required init(sender: AnyObject, name: String, data: AnyObject?) {
        super.init(sender: sender, name: name, data: data)
    }
}

public protocol IEventHandler {
    var id: Int { get }
    var event: String { get }
    var once: Bool { get }
    func handle(event:IEvent) -> Void
}

struct id_gen {
    static var id : Int = 0
    static func gen() -> Int {
        return (++self.id)
    }
}


public struct EventHandler : IEventHandler {
    
    //var event: String
    public let id = id_gen.gen()
    public let event: String
    public let once: Bool
    let handler: (event:IEvent) -> Void
    
    public func handle(event: IEvent) {
        /*let task : BFTask
        
        switch self.handler {
        case .Sync(let handle):
            handle(event: event)
            task = BFTask(result: nil)
        case .Async(let handle):
            task = handle(event: event)
        }
        
        return task*/
        self.handler(event: event)
    }
}

public struct TEventHandler<T: IEvent> : IEventHandler {
    
    //var event: String
    public let id = id_gen.gen()
    public let event: String
    public let once: Bool
    let handler: (event:T) -> Void
    
    public func handle(event: IEvent) {
        
        if event is T {
            self.handler(event: event as! T)
        }
        
        
        /*let task : BFTask
        
        switch self.handler {
        case .Sync(let handle):
            handle(event: event as! T)
            task = BFTask(result: nil)
        case .Async(let handle):
            task = handle(event: event as! T)
        }
        
        return task*/
    }
}

enum EHandler {
    case Sync((event: IEvent) -> Void)
    case Async((event: IEvent) -> BFTask)
}

public func ==<T: IEvent>(lhs: TEventHandler<T>, rhs: TEventHandler<T>) -> Bool {
    return lhs.id == rhs.id
}

public func ==(lhs: EventHandler, rhs: EventHandler) -> Bool {
    return lhs.id == rhs.id
}

public protocol EventConvertible {
    var eventName : String { get }
}

extension String : EventConvertible {
    public var eventName : String {
        return self
    }
}


public class EventEmitter {
    var handlers : [IEventHandler] = []
    public var emitQueue : dispatch_queue_t?
    
    /*public func on<T: IEvent>(event: String, async: (event: T) -> BFTask) -> TEventHandler<T> {
        let eventHandler = TEventHandler<T>(event:event,once: false, handler: .Async(async))
        return self.listen(eventHandler) as! TEventHandler<T>
    }*/
    
    public func on<T: IEvent>(event: EventConvertible, handler: (event: T) -> Void) -> TEventHandler<T> {
        let eventHandler = TEventHandler<T>(event:event.eventName,once: false, handler: handler)
        return self.listen(eventHandler) as! TEventHandler<T>
    }
    
    public func on (event: EventConvertible, handler: (event: IEvent) -> Void) -> EventHandler {
        let eventHandler = EventHandler(event:event.eventName,once: false, handler: handler)
        return self.listen(eventHandler) as! EventHandler
    }
    
    public func once(event: EventConvertible, handler: (data: IEvent) -> Void) -> EventHandler {
        let eventHandler = EventHandler(event:event.eventName, once: true, handler: handler)
        return self.listen(eventHandler) as! EventHandler
    }
    
    private func listen(eventHandler: IEventHandler) -> IEventHandler {
        self.handlers.append(eventHandler)
        return eventHandler
    }
    
    public func off (handler: IEventHandler) -> Self {
        self.off(handler.id)
        return self
    }
    
    public func off(id: Int) -> Self {
        var index = 0
        let hdl = self.handlers
        for handler in hdl {
            if handler.id == id {
                self.handlers.removeAtIndex(index)
            }
            index++
        }
        return self
    }
    
    public func off() -> Self {
        self.handlers = []
        return self
    }
    
    public func emit(eventName: EventConvertible) -> Self {
        let event = Event(sender: self as! AnyObject, name: eventName.eventName, data: nil)
        return self.emit(eventName, data: event)
    }
    
    public func emit<T> (eventName: EventConvertible, data: T? = nil) -> Self {
        /*dispatch_async(self.emitQueue ?? dispatch_get_main_queue(), { () -> Void in
            let event: IEvent
            if let e = data as? IEvent {
                event = e
            } else {
                event = TEvent<T>(sender: self as! AnyObject, name: eventName, data: data as? AnyObject)
            }
            var i = 0
            var promises : [BFTask] = []
            for handler in self.handlers {
                if handler.event == eventName || handler.event == "all" {
                    let task = handler.handle(event)
                    promises.append(task)
                    if handler.once {
                        self.handlers.removeAtIndex(i)
                    }
                
                }
                
                i++
            }
            
        })*/
        
        let event: IEvent
        if let e = data as? IEvent {
            event = e
        } else {
            event = TEvent<T>(sender: self as! AnyObject, name: eventName.eventName, data: data as? AnyObject)
        }
        var i = 0
        
        for handler in self.handlers {
            if handler.event == eventName.eventName || handler.event == "all" {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler.handle(event)
                })
                
                
                if handler.once {
                    self.handlers.removeAtIndex(i)
                }
                
            }
            
            i++
        }

        
        return self
    }
    
}