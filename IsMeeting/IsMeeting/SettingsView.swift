//
//  SettingsView.swift
//  IsMeeting
//
//  Created by Jorge Pereira on 17/04/2026.
//

import AppKit
import ServiceManagement
import SwiftUI

// NSViewRepresentable wrapper that forces a true single-line NSTextField
private struct SingleLineTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.cell?.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SingleLineTextField
        init(_ parent: SingleLineTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 460)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("webhookURL") private var webhookURL = ""

    var body: some View {
        Form {
        
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Revert toggle if the system call fails
                            launchAtLogin = !enabled
                        }
                    }
                HStack(alignment: .center) {
                    Text("Webhook URL")
                    Spacer()
                    Text("https://")
                        .foregroundStyle(.secondary)
                    SingleLineTextField(text: $webhookURL)
                        .frame(maxWidth: 200, maxHeight: 22)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            
            } footer: {
                Text("Enter the URL without https://. Called with a JSON payload whenever your meeting status changes.")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Feedback")
                        Text("Help us make IsMeeting better.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Report") { }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

// MARK: - Previews

#Preview("General") {
    GeneralSettingsTab()
        .frame(width: 460)
}

#Preview("About") {
    AboutTab()
        .frame(width: 460, height: 260)
}

// MARK: - About

struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("IsMeeting")
                .font(.title2.bold())

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)

            Text("© 2026 Jorge Pereira. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
