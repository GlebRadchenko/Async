//
//  Async.swift
//  Async
//
//  Created by Gleb Radchenko on 10/4/18.
//  Copyright © 2018 Gleb Radchenko. All rights reserved.
//

import Foundation

class Async {
    class DispatchObject: Dispatcher {
        static let threadPool = ThreadPool()
        
        var isSerialRunning: Bool = false
        var isSerial: Bool
        
        var lock = NSLock()
        
        var tasks: [Block<Void>] = []
        
        func getNextTask() -> Block<Void> {
            fatalError("\(#function) not overrided")
        }
        
        init(serial: Bool = false) {
            self.isSerial = serial
        }
    }
    
    class DispatchQueue: DispatchObject {
        static let global = DispatchQueue()
        
        override func getNextTask() -> Block<Void> {
            return tasks.removeFirst()
        }
    }
    
    class DispatchStack: DispatchObject {
        static let global = DispatchStack()
        
        override func getNextTask() -> Block<Void> {
            return tasks.removeLast()
        }
    }
    
    class ThreadPool {
        fileprivate var condition = NSCondition()
        
        fileprivate(set) var maxThreadCount: Int
        fileprivate(set) var activeThreadCount = 0
        fileprivate(set) var currentThreadCount = 0
        
        fileprivate var tasks: [Block<Void>] = []
        
        init(maxThreadCount: Int = 256) {
            self.maxThreadCount = maxThreadCount
        }
        
        fileprivate var idleThreadCount: Int {
            return currentThreadCount - activeThreadCount
        }
        
        func addTask(_ block: @escaping Block<Void>) {
            condition.lock()
            tasks.append(block)
            
            if tasks.count > idleThreadCount && currentThreadCount < maxThreadCount {
                Thread.detachNewThread { [weak self] in
                    guard let wSelf = self else { return }
                    wSelf.loop()
                }
                
                currentThreadCount += 1
            }
            
            condition.signal()
            condition.unlock()
        }
        
        fileprivate func loop() {
            condition.lock()
            
            while true {
                while tasks.isEmpty { condition.wait() }
                
                let task = tasks.removeFirst()
                
                activeThreadCount += 1
                
                condition.unlock()
                task()
                condition.lock()
                
                activeThreadCount -= 1
            }
        }
    }
}
