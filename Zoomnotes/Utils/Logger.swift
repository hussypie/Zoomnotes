//
//  Logger.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import os

protocol Logger {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func fatal(_ message: String)
}
