//
//  Dispatcher.swift
//  Async
//
//  Created by Gleb Radchenko on 10/4/18.
//  Copyright © 2018 Gleb Radchenko. All rights reserved.
//

import Foundation

typealias Block<T> = () -> T
typealias ThrowingBlock<T> = () throws -> T

protocol Dispatcher: class {
    static var threadPool: Async.ThreadPool { get }
    
    var isSerialRunning: Bool { get set }
    var isSerial: Bool { get set }
    
    var lock: NSLock { get set }
    
    var tasks: [Block<Void>] { get set }
    
    func async(_ block: @escaping Block<Void>)
    
    func sync<T>(_ block: @escaping Block<T>) -> T
    func sync<T>(_ block: @escaping ThrowingBlock<T>) throws -> T
    
    func getNextTask() -> Block<Void>
}

extension Dispatcher {
    func async(_ block: @escaping Block<Void>) {
        lock.lock(); defer { lock.unlock() }
        
        tasks.append(block)
        
        if isSerial && !isSerialRunning {
            isSerialRunning = true
            dispatch()
        } else if !isSerial {
            dispatch()
        }
    }
    
    func sync<T>(_ block: @escaping Block<T>) -> T {
        let condition = NSCondition()
        var finised = false
        
        var result: T?
        
        async {
            result = block()
            
            condition.lock()
            finised.toggle()
            condition.signal()
            condition.unlock()
        }
        
        condition.lock()
        while !finised { condition.wait() }
        condition.unlock()
        
        return result!
    }
    
    func sync<T>(_ block: @escaping ThrowingBlock<T>) throws -> T {
        let condition = NSCondition()
        var finised = false
        
        var r: T?
        var e: Error?
        
        async {
            do {
                r = try block()
            } catch {
                e = error
            }
            
            condition.lock()
            finised.toggle()
            condition.signal()
            condition.unlock()
        }
        
        condition.lock()
        while !finised { condition.wait() }
        condition.unlock()
        
        if let result = r {
            return result
        } else {
            throw e!
        }
    }
    
    func dispatch() {
        Self.threadPool.addTask { [weak self] in
            guard let wSelf = self else { return }
            wSelf.performTask()
        }
    }
    
    fileprivate func performTask() {
        lock.lock()
        let task = getNextTask()
        lock.unlock()
        
        task()
        
        if isSerial {
            lock.lock()
            
            if tasks.isEmpty {
                isSerialRunning = false
            } else {
                dispatch()
            }
            
            lock.unlock()
        }
    }
}
