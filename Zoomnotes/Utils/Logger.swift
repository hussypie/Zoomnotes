//
//  Logger.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Willow

protocol LoggerProtocol {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

struct TestLogger: LoggerProtocol {
    func info(_ message: String) {
        print(message)
    }

    func warning(_ message: String) {
        print(message)
    }

    func error(_ message: String) {
        print(message)
    }
}

struct DebugLogger: LoggerProtocol {
    private let logger = Logger(logLevels: [.all],
                                writers: [OSLogWriter(subsystem: "com.berci.app.debug.zoomnotes",
                                                      category: "debug")])

    func info(_ message: String) {
        self.logger.infoMessage(message)
    }

    func warning(_ message: String) {
        self.logger.warnMessage(message)
    }

    func error(_ message: String) {
        self.logger.errorMessage(message)
    }
}

struct ProductionLogger: LoggerProtocol {
    let logger: Logger = {
        let queue = DispatchQueue(label: "logger.queue", qos: .utility)
        return Logger(logLevels: [.all],
                      writers: [OSLogWriter(subsystem: "com.berci.app.zoomnotes", category: "prod")],
                      executionMethod: .asynchronous(queue: queue))
    }()

    func info(_ message: String) {
        logger.infoMessage(message)
    }

    func warning(_ message: String) {
        logger.warnMessage(message)
    }

    func error(_ message: String) {
        logger.errorMessage(message)
    }
}
