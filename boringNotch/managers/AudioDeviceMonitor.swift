import Foundation
import CoreAudio

/// Monitors system audio output device changes and fires when AirPods connect.
final class AudioDeviceMonitor {
    static let shared = AudioDeviceMonitor()

    private let queue = DispatchQueue(label: "AudioDeviceMonitor.queue")
    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
    private var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var isListening = false
    private var lastDefaultDeviceID: AudioObjectID? = nil

    func start() {
        guard !isListening else { return }

        var addr = propertyAddress
        let status = AudioObjectAddPropertyListenerBlock(systemObjectID, &addr, queue) {
            [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        if status != noErr {
            print("AudioDeviceMonitor: Failed to add property listener: \(status)")
            return
        }
        isListening = true
        // Seed initial state without notifying
        lastDefaultDeviceID = currentDefaultOutputDeviceID()
    }

    func stop() {
        guard isListening else { return }
        var addr = propertyAddress
        AudioObjectRemovePropertyListenerBlock(systemObjectID, &addr, queue, { _, _ in })
        isListening = false
    }

    private func handleDefaultDeviceChanged() {
        let currentID = currentDefaultOutputDeviceID()
        guard currentID != 0 else { return }

        // Avoid duplicate notifications when unchanged
        if let last = lastDefaultDeviceID, last == currentID {
            return
        }
        lastDefaultDeviceID = currentID

        let name = deviceName(for: currentID)
        // Heuristic: match any AirPods name
        if name.lowercased().contains("airpods") {
            // Post an initial toast quickly, then refine value via retries.
            let immediate = AirPodsBatteryReader.shared.currentBatteryLevel()
            let initial = immediate ?? 0.85
            DispatchQueue.main.async {
                BoringViewCoordinator.shared.showAirPodsConnected(batteryLevel: initial)
            }

            // Retry a few times regardless of immediate success; IORegistry may settle late.
            let delays: [Double] = [0.4, 0.9, 1.6, 2.5]
            for d in delays {
                queue.asyncAfter(deadline: .now() + d) {
                    if let level = AirPodsBatteryReader.shared.currentBatteryLevel() {
                        DispatchQueue.main.async {
                            BoringViewCoordinator.shared.showAirPodsConnected(batteryLevel: level)
                        }
                    }
                }
            }
        }
    }

    private func currentDefaultOutputDeviceID() -> AudioObjectID {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(systemObjectID, &addr, 0, nil, &size, &deviceID)
        if status != noErr {
            print("AudioDeviceMonitor: Failed to get default output device: \(status)")
            return 0
        }
        return deviceID
    }

    private func deviceName(for deviceID: AudioObjectID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &name)
        if status != noErr || (name as String).isEmpty {
            // Fallback for older keys
            addr.mSelector = kAudioDevicePropertyDeviceNameCFString
            size = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &name)
            if status != noErr {
                return ""
            }
        }
        return name as String
    }
}
