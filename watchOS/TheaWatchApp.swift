//
//  TheaWatchApp.swift
//  Thea Watch
//
//  Created by Claude Code on 2026-01-24
//  Copyright © 2026 Thea. All rights reserved.
//

import SwiftUI

@main
struct TheaWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("Thea")
                    .font(.headline)

                Text("AI Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Thea")
        }
    }
}

#Preview {
    ContentView()
}
