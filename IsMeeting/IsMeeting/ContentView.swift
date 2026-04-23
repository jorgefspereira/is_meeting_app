//
//  ContentView.swift
//  IsMeeting
//
//  Created by Jorge Pereira on 17/04/2026.
//

import CoreAudio
import CoreMediaIO
import SwiftUI

@Observable
final class MeetingStatusMonitor {
    var isInMeeting = false
    private var timer: Timer?
    private var lastKnownState: Bool?

    init() {
        let initial = isCameraInUseSomewhere() || isMicrophoneInUseSomewhere()
        isInMeeting = initial
        lastKnownState = initial
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func updateStatus() {
        let current = isCameraInUseSomewhere() || isMicrophoneInUseSomewhere()
        guard current != lastKnownState else { return }
        lastKnownState = current
        isInMeeting = current
        sendWebhook(isInMeeting: current)
    }

    private func sendWebhook(isInMeeting: Bool) {
        let stored = UserDefaults.standard.string(forKey: "webhookURL") ?? ""
        guard !stored.isEmpty, let url = URL(string: "https://" + stored) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["state": isInMeeting ? "on" : "off"])

        URLSession.shared.dataTask(with: request).resume()
    }

    // CoreMediaIO: detects any camera running in any process (including Continuity Camera)
    private func isCameraInUseSomewhere() -> Bool {
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        guard count > 0 else { return false }
        var deviceIDs = [CMIOObjectID](repeating: 0, count: count)
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataSize, &deviceIDs)

        for deviceID in deviceIDs {
            var runningOpa = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            CMIOObjectGetPropertyData(deviceID, &runningOpa, 0, nil, size, &size, &isRunning)
            if isRunning != 0 { return true }
        }
        return false
    }

    // CoreAudio: detects any audio input device (including Bluetooth HFP) running in any process
    private func isMicrophoneInUseSomewhere() -> Bool {
        var hwAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &hwAddress, 0, nil, &dataSize)
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return false }
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &hwAddress, 0, nil, &dataSize, &deviceIDs)

        for deviceID in deviceIDs {
            // Only consider devices that have input streams
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr,
                  inputSize > 0 else { continue }

            var runningSomewhereAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &runningSomewhereAddress, 0, nil, &runningSize, &isRunning) == noErr,
               isRunning != 0 {
                return true
            }
        }
        return false
    }
}

private struct MenuItemButton: View {
    let action: () -> Void
    let label: String
    let icon: String
    let shortcut: String
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16, alignment: .center)
                Text(label)
                Spacer()
                Text(shortcut)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                    .frame(width: 28, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 4)
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private func openSettingsWindow(_ openSettings: () -> Void) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    openSettings()

    // Watch for the settings window to close, then go back to accessory mode
    NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: nil,
        queue: .main
    ) { _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if NSApp.windows.allSatisfy({ !$0.isVisible || $0.title.isEmpty }) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

struct ContentView: View {
    @Environment(MeetingStatusMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Status row
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isInMeeting ? Color.red : Color.green)
                    .frame(width: 10, height: 10)
                    .frame(width: 16, alignment: .center)
                Text(monitor.isInMeeting ? "In a meeting" : "Not in a meeting")
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            MenuItemButton(action: {
                NSApp.keyWindow?.close()
                openSettingsWindow { openSettings() }
            }, label: "Settings", icon: "gearshape", shortcut: "⌘ ,")

            MenuItemButton(action: {
                NSApp.terminate(nil)
            }, label: "Quit IsMeeting", icon: "power", shortcut: "⌘ Q")
        }
        .frame(width: 220)
    }
}

#Preview {
    ContentView()
        .environment(MeetingStatusMonitor())
}
