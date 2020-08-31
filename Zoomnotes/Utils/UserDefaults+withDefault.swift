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
}

extension UserDefaults {
    func withDefault<T>(_ key: UserDefaultsKey, default value: T) -> T {
        return self.object(forKey: key.rawValue) as? T ?? value
    }
}
