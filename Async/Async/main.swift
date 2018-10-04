//
//  main.swift
//  Async
//
//  Created by Gleb Radchenko on 10/4/18.
//  Copyright © 2018 Gleb Radchenko. All rights reserved.
//

import Foundation

(0...100).forEach { (i) in
    Async.DispatchQueue.global.async { print(i) }
}

RunLoop.main.run()

