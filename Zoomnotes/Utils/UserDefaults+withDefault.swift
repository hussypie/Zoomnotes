//
//  UserDefaults+withDefault.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 31..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

enum UserDefaultsKey: String {
    case statusBarVisible = "statusBarPreferenceKey"
    case rootDirectoryId = "rootDirectoryIdKey"
}

extension UserDefaults {
    func withDefaultValue<T>(_ key: String, default value: T) -> T {
        return self.object(forKey: key) as? T ?? value
    }

    func withDefault<T>(_ key: UserDefaultsKey, default value: T) -> T {
        return self.withDefaultValue(key.rawValue, default: value)
    }
}
