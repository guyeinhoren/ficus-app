//
//  ficusApp.swift
//  ficus
//
//  Created by גיא אינהורן on 04/10/2025.
//

import SwiftData
import SwiftUI

@main
struct ficusApp: App {
    @State private var session = FocusSession()
    private let container = FocusStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                // The whole interface is Hebrew, so it always lays out right-to-left.
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(container)
    }
}
