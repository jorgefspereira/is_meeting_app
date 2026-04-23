//
//  IsMeetingApp.swift
//  IsMeeting
//
//  Created by Jorge Pereira on 17/04/2026.
//

import AppKit
import SwiftUI

@main
struct IsMeetingApp: App {
    @State private var monitor = MeetingStatusMonitor()

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(monitor)
        } label: {
            // Icon reflects meeting status so the user can see state at a glance
            Image(systemName: monitor.isInMeeting ? "video.fill" : "video")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
