//
//  OkayableTextfield.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 18..
//  Copyright © 2020. Berci. All rights reserved.
//

import SwiftUI
import Introspect

struct OkayableTextfield: View {
    @State var text: String = String.empty
    private let initialText: String
    private let placeholder: String
    private let onCommit: (String) -> Void

    init(_ placeholder: String, text: String, onCommit: @escaping (String) -> Void) {
        self.initialText = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }

    var body: some View {
        TextField(placeholder,
                  text: $text,
                  onEditingChanged: { _ in },
                  onCommit: { self.onCommit(self.text)
        }).introspectTextField { textfield in
            textfield.returnKeyType = .done
        }.onAppear(perform: { self.text = self.initialText })
    }
}

struct OkayableTextfield_Previews: PreviewProvider {
    static var previews: some View {
        OkayableTextfield("Hello", text: "World", onCommit: { print($0) })
    }
}
