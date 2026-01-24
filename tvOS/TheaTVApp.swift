//
//  TheaTVApp.swift
//  Thea TV
//
//  Created by Claude Code on 2026-01-24
//  Copyright © 2026 Thea. All rights reserved.
//

import SwiftUI

@main
struct TheaTVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ConversationsView()
                .tabItem {
                    Label("Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

struct HomeView: View {
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "brain.fill")
                .font(.system(size: 120))
                .foregroundStyle(.blue)

            Text("Thea")
                .font(.system(size: 60, weight: .bold))

            Text("Your AI Assistant on Apple TV")
                .font(.title2)
                .foregroundStyle(.secondary)

            Button(action: {}) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start Voice Conversation")
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(80)
    }
}

struct ConversationsView: View {
    var body: some View {
        VStack {
            Text("Recent Conversations")
                .font(.title)

            Text("No conversations yet")
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)

            Text("Configure Thea for your TV")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
