import AppKit
import Combine
import CryptoKit

enum ClipboardKind: Equatable {
    case text
    case image
}

struct ClipboardEntry: Identifiable, Equatable {
    let id = UUID()
    let kind: ClipboardKind
    let string: String?
    let image: NSImage?
    let date: Date
    let dataHash: String
    let appName: String?
    let bundleIdentifier: String?

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.kind == rhs.kind && lhs.dataHash == rhs.dataHash
    }
}

class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardEntry] = []

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let maxItems = 30

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        stopMonitoring()
        // OPTIMIZATION: Increased polling interval from 1.0s to 1.5s (33% less CPU usage)
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        // OPTIMIZATION: Early return if no changes detected
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        capture(from: pb)
    }

    private func capture(from pasteboard: NSPasteboard) {
        // 1) Try image first
        if let imageEntry = readImageEntry(from: pasteboard) {
            if items.first?.dataHash != imageEntry.dataHash {
                items.insert(imageEntry, at: 0)
                trim()
            }
            return
        }

        // 2) Fall back to text (plain / rtf / html)
        if let textEntry = readTextEntry(from: pasteboard) {
            if items.first?.dataHash != textEntry.dataHash {
                items.insert(textEntry, at: 0)
                trim()
            }
            return
        }
    }

    private func readTextEntry(from pasteboard: NSPasteboard) -> ClipboardEntry? {
        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName
        let bundle = app?.bundleIdentifier
        if let s = pasteboard.string(forType: .string) {
            let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return nil }
            let hash = sha256Hex(Data(normalized.utf8))
            return ClipboardEntry(kind: .text, string: normalized, image: nil, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
        }

        if let item = pasteboard.pasteboardItems?.first {
            for type in item.types {
                if type.rawValue == "public.utf8-plain-text" || type.rawValue == "public.utf16-external-plain-text" || type == .rtf || type == .html {
                    if let data = item.data(forType: type) {
                        if type == .rtf {
                            if let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
                                let text = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    let hash = sha256Hex(Data(text.utf8))
                                    return ClipboardEntry(kind: .text, string: text, image: nil, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
                                }
                            }
                        } else if type == .html {
                            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                                let text = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    let hash = sha256Hex(Data(text.utf8))
                                    return ClipboardEntry(kind: .text, string: text, image: nil, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
                                }
                            }
                        } else if let text = String(data: data, encoding: .utf8) {
                            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !normalized.isEmpty {
                                let hash = sha256Hex(Data(normalized.utf8))
                                return ClipboardEntry(kind: .text, string: normalized, image: nil, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func readImageEntry(from pasteboard: NSPasteboard) -> ClipboardEntry? {
        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName
        let bundle = app?.bundleIdentifier
        // TIFF
        if let data = pasteboard.data(forType: .tiff), let img = NSImage(data: data) {
            let hash = sha256Hex(data)
            return ClipboardEntry(kind: .image, string: nil, image: img, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
        }
        // PNG
        let pngType = NSPasteboard.PasteboardType("public.png")
        if let data = pasteboard.data(forType: pngType), let img = NSImage(data: data) {
            let hash = sha256Hex(data)
            return ClipboardEntry(kind: .image, string: nil, image: img, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
        }
        // General image class read
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], let img = images.first {
            // Compute hash from TIFF representation if available
            if let tiff = img.tiffRepresentation {
                let hash = sha256Hex(tiff)
                return ClipboardEntry(kind: .image, string: nil, image: img, date: Date(), dataHash: hash, appName: name, bundleIdentifier: bundle)
            }
            return ClipboardEntry(kind: .image, string: nil, image: img, date: Date(), dataHash: UUID().uuidString, appName: name, bundleIdentifier: bundle)
        }
        return nil
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func trim() {
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    func clear() {
        items.removeAll()
    }

    func copyToPasteboard(_ entry: ClipboardEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.kind {
        case .text:
            pb.setString(entry.string ?? "", forType: .string)
        case .image:
            if let image = entry.image {
                pb.writeObjects([image])
            }
        }
    }
}
