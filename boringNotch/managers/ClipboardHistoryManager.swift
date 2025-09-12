import AppKit
import Combine

struct ClipboardEntry: Identifiable, Equatable {
    let id = UUID()
    let string: String
    let date: Date

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.string == rhs.string
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
        // Poll the pasteboard change count with a modest interval
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        capture(from: pb)
    }

    private func capture(from pasteboard: NSPasteboard) {
        // Prefer string content
        if let s = pasteboard.string(forType: .string) {
            let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }

            // Avoid consecutive duplicates
            if items.first?.string == normalized { return }

            items.insert(ClipboardEntry(string: normalized, date: Date()), at: 0)
            trim()
            return
        }

        // Try common alternative text types
        if let item = pasteboard.pasteboardItems?.first {
            for type in item.types {
                if type.rawValue == "public.utf8-plain-text" || type.rawValue == "public.utf16-external-plain-text" || type == .rtf || type == .html {
                    if let data = item.data(forType: type) {
                        if type == .rtf {
                            if let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
                                let text = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty { insert(text) }
                                return
                            }
                        } else if type == .html {
                            if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                                let text = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty { insert(text) }
                                return
                            }
                        } else if let text = String(data: data, encoding: .utf8) {
                            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !normalized.isEmpty { insert(normalized) }
                            return
                        }
                    }
                }
            }
        }
    }

    private func insert(_ text: String) {
        if items.first?.string == text { return }
        items.insert(ClipboardEntry(string: text, date: Date()), at: 0)
        trim()
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
        pb.setString(entry.string, forType: .string)
    }
}

