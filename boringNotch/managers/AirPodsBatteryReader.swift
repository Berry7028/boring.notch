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
        // Known keys seen in IORegistry / Bluetooth plists for Apple audio devices:
        // - BatteryPercentCombined (overall, often present on AirPods Pro)
        // - BatteryPercentLeft / BatteryPercentRight (per-earbud)
        // - BatteryPercentSingle (single-battery headsets)
        // - BatteryPercent (generic single value)
        // - HeadsetBattery (string like "71%" on some stacks)
        // - BatteryPercentCase (case battery — use only as a last resort)

        // 1) Combined (best single indicator when present)
        if let combined = Self.percentInt(dict,
                                          keys: ["BatteryPercentCombined", "Battery Percent Combined"]) {
            if let normalized = Self.normalize0to100(combined) {
                return Double(normalized) / 100.0
            }
        }

        // 2) Left/Right — average if both available; otherwise whichever ear we have
        let left = Self.percentInt(dict, keys: ["BatteryPercentLeft", "Battery Percent Left"]).flatMap(Self.normalize0to100)
        let right = Self.percentInt(dict, keys: ["BatteryPercentRight", "Battery Percent Right"]).flatMap(Self.normalize0to100)
        if let l = left, let r = right {
            // If both values are valid and greater than 0, take the average
            if l > 0 && r > 0 {
                return Double(l + r) / 2.0 / 100.0
            }
            // If one is 0 (e.g., in case), use the non-zero value
            if l > 0 { return Double(l) / 100.0 }
            if r > 0 { return Double(r) / 100.0 }
            // Both are 0
            return 0.0
        }
        if let l = left { return Double(l) / 100.0 }
        if let r = right { return Double(r) / 100.0 }

        // 3) Single battery value (various keys)
        if let single = Self.percentInt(
            dict,
            keys: ["BatteryPercent", "Battery Percent", "BatteryPercentSingle", "Battery Percent Single", "HeadsetBattery"]
        ), let normalized = Self.normalize0to100(single) {
            return Double(normalized) / 100.0
        }

        // 4) Case battery (only if nothing else is available)
        if let casePct = Self.percentInt(dict, keys: ["BatteryPercentCase", "Battery Percent Case"]),
           let normalized = Self.normalize0to100(casePct)
        {
            return Double(normalized) / 100.0
        }

        return nil
    }

    /// Extract an Int percent from any of the provided keys.
    private static func percentInt(_ dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let raw = dict[key] { return intValue(raw) }
        }
        return nil
    }

    /// Convert mixed numeric/string (e.g. 71 or "71%") into Int if possible.
    private static func intValue(_ any: Any?) -> Int? {
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String {
            // Strip non-digits like "%" or spaces
            let digits = s.filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }

    /// Clamp to 0...100 and discard obviously invalid values (<0 or >1000 etc.)
    private static func normalize0to100(_ value: Int) -> Int? {
        guard value >= 0 && value <= 1000 else { return nil }
        return min(max(value, 0), 100)
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

        let combined = value(for: "BatteryPercentCombined") ?? value(for: "Battery Percent Combined")
        if let c = combined, let norm = Self.normalize0to100(c) { return Double(norm) / 100.0 }

        let left = value(for: "BatteryPercentLeft") ?? value(for: "Battery Percent Left")
        let right = value(for: "BatteryPercentRight") ?? value(for: "Battery Percent Right")
        if let l = left.flatMap(Self.normalize0to100), let r = right.flatMap(Self.normalize0to100) {
            // If both values are valid and greater than 0, take the average
            if l > 0 && r > 0 {
                return Double(l + r) / 2.0 / 100.0
            }
            // If one is 0 (e.g., in case), use the non-zero value
            if l > 0 { return Double(l) / 100.0 }
            if r > 0 { return Double(r) / 100.0 }
            // Both are 0
            return 0.0
        }
        if let l = left.flatMap(Self.normalize0to100) { return Double(l) / 100.0 }
        if let r = right.flatMap(Self.normalize0to100) { return Double(r) / 100.0 }

        let single = value(for: "BatteryPercent")
            ?? value(for: "Battery Percent")
            ?? value(for: "BatteryPercentSingle")
            ?? value(for: "Battery Percent Single")
            ?? value(for: "HeadsetBattery")
            ?? value(for: "BatteryPercentCase") // last resort
        if let s = single.flatMap(Self.normalize0to100) { return Double(s) / 100.0 }
        return nil
    }
}
