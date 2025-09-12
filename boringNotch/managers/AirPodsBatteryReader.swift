import Foundation
import IOKit

/// Reads AirPods battery information from IORegistry.
/// This uses the AppleDeviceManagementHIDEventService entries that expose
/// keys like BatteryPercentLeft/Right/Case for Apple accessories.
final class AirPodsBatteryReader {
    static let shared = AirPodsBatteryReader()

    /// Returns battery level 0.0...1.0 if found, otherwise nil.
    func currentBatteryLevel() -> Double? {
        // 1) IORegistry (preferred)
        if let lvl = readFromIORegistry() {
            return lvl
        }
        // 2) System Bluetooth preferences as fallback
        if let lvl = readFromBluetoothPlist() {
            return lvl
        }
        // 3) Shell ioreg parsing as a last resort
        if let lvl = readFromIoregShell() {
            return lvl
        }
        // 4) User-level Bluetooth prefs (rare)
        if let lvl = readFromUserBluetoothPlist() {
            return lvl
        }
        return nil
    }

    private func readFromIORegistry() -> Double? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }

        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanagedDict: Unmanaged<CFMutableDictionary>? = nil
            let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0)
            guard kr == KERN_SUCCESS, let props = unmanagedDict?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Identify AirPods by product name keys.
            let product = (props["Product"] as? String)
                ?? (props["Product Name"] as? String)
                ?? (props["DeviceName"] as? String)
                ?? (props["BSD Name"] as? String)
                ?? ""
            if !product.lowercased().contains("airpods") { continue }

            if let lvl = batteryLevel(from: props) {
                return lvl
            }
        }
        return nil
    }

    private func readFromBluetoothPlist() -> Double? {
        let path = "/Library/Preferences/com.apple.Bluetooth.plist"
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else { return nil }
        return parseDeviceCache(dict["DeviceCache"]) ?? parseNearbyDevices(dict["NearbyDevices"]) // some macOS store here
    }

    private func readFromUserBluetoothPlist() -> Double? {
        // Fallback to user-level; may not contain DeviceCache on modern macOS
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let byHost = try? FileManager.default.contentsOfDirectory(atPath: "\(home)/Library/Preferences/ByHost")
            .first { $0.hasPrefix("com.apple.Bluetooth") && $0.hasSuffix(".plist") }
        if let byHost, let dict = NSDictionary(contentsOfFile: "\(home)/Library/Preferences/ByHost/\(byHost)") as? [String: Any] {
            return parseDeviceCache(dict["DeviceCache"]) ?? parseNearbyDevices(dict["NearbyDevices"]) ?? parseDeviceCache(dict)
        }
        return nil
    }

    private func parseDeviceCache(_ any: Any?) -> Double? {
        guard let devices = any as? [String: Any] else { return nil }
        for (_, value) in devices {
            guard let dev = value as? [String: Any] else { continue }
            let name = (dev["Name"] as? String) ?? (dev["ProductName"] as? String) ?? ""
            if !name.lowercased().contains("airpods") { continue }
            if let lvl = batteryLevel(from: dev) { return lvl }
        }
        return nil
    }

    private func parseNearbyDevices(_ any: Any?) -> Double? {
        guard let devices = any as? [[String: Any]] else { return nil }
        for dev in devices {
            let name = (dev["Name"] as? String) ?? (dev["ProductName"] as? String) ?? ""
            if !name.lowercased().contains("airpods") { continue }
            if let lvl = batteryLevel(from: dev) { return lvl }
        }
        return nil
    }

    private func batteryLevel(from dict: [String: Any]) -> Double? {
        // Prefer ears average, then single, then case
        let left = Self.intValue(dict["BatteryPercentLeft"]) ?? Self.intValue(dict["Battery Percent Left"]) // sometimes spaced
        let right = Self.intValue(dict["BatteryPercentRight"]) ?? Self.intValue(dict["Battery Percent Right"]) // sometimes spaced
        let single = Self.intValue(dict["BatteryPercent"]) ?? Self.intValue(dict["BatteryPercentSingle"]) ?? Self.intValue(dict["Battery Percent"]) ?? Self.intValue(dict["Battery Percent Single"]) ?? Self.intValue(dict["BatteryPercentCase"]) ?? Self.intValue(dict["Battery Percent Case"]) // last resort

        if let l = left, let r = right, (l > 0 || r > 0) {
            return Double(l + r) / 2.0 / 100.0
        }
        if let s = single { return Double(s) / 100.0 }
        return nil
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }

    private func readFromIoregShell() -> Double? {
        // Invoke ioreg to fetch battery keys; parse best available value.
        // This path helps on systems where CFProperties don't expose expected keys immediately.
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-r", "-n", "AppleDeviceManagementHIDEventService", "-l"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return nil
        }

        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8)?.lowercased(), out.contains("airpods") else {
            return nil
        }

        func value(for key: String) -> Int? {
            // match: "BatteryPercentLeft" = 91
            let pattern = "\\b\(key.lowercased())\\b[^=]*=\\s*([0-9]{1,3})"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(out.startIndex..<out.endIndex, in: out)
                if let match = regex.firstMatch(in: out, options: [], range: range), match.numberOfRanges > 1 {
                    if let r = Range(match.range(at: 1), in: out) {
                        return Int(out[r])
                    }
                }
            }
            return nil
        }

        let left = value(for: "BatteryPercentLeft") ?? value(for: "Battery Percent Left")
        let right = value(for: "BatteryPercentRight") ?? value(for: "Battery Percent Right")
        let single = value(for: "BatteryPercent") ?? value(for: "Battery Percent") ?? value(for: "BatteryPercentSingle") ?? value(for: "Battery Percent Single") ?? value(for: "BatteryPercentCase")

        if let l = left, let r = right, (l > 0 || r > 0) {
            return Double(l + r) / 2.0 / 100.0
        }
        if let s = single { return Double(s) / 100.0 }
        return nil
    }
}
