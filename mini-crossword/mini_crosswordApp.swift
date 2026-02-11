//
//  mini_crosswordApp.swift
//  mini-crossword
//
//  Created by Axel Langenskiöld on 2026-02-06.
//

import SwiftUI

@main
struct mini_crosswordApp: App {
    init() {
        AdMobManager.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
