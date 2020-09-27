//
//  SettingsView.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 31..
//  Copyright © 2020. Berci. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    private var statusBarPreference: Binding<Bool> {
        Binding(get: {
            UserDefaults.standard.withDefault(.statusBarVisible, default: true)
        }, set: {
            UserDefaults.standard.set($0, forKey: UserDefaultsKey.statusBarVisible.rawValue)
        })
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: self.statusBarPreference) {
                    Text("Hide status bar")
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
