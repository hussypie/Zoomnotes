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

    func set<T>(_ key: UserDefaultsKey, value: T) {
        self.set(value, forKey: key.rawValue)
    }

    func set(_ value: UUID, forKey: String) {
        self.set(value.uuidString, forKey: forKey)
    }

    func uuid(forKey: String) -> UUID? {
        guard let uuidString = self.string(forKey: forKey) else { return nil }
        return UUID(uuidString: uuidString)
    }
}

extension UserDefaults {
    static func mock(name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
