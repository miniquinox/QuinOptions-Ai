//
//  OptionsAiApp.swift
//  OptionsAi
//
//  Created by Quino on 3/3/24.
//

import SwiftUI
import Firebase

@main
struct OptionsAiApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
