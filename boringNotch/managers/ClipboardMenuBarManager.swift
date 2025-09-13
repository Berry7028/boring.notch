import Cocoa
import SwiftUI

class ClipboardMenuBarManager: NSObject, NSMenuDelegate {
    static let shared = ClipboardMenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    override init() {
        super.init()
    }
    
    func setupMenuBarItem() {
        // Create status item with clipboard icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use clipboard system icon + label text
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard History")
            button.image?.size = NSSize(width: 16, height: 16)
            button.title = " クリップボード"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // Right click - show context menu
            showContextMenu()
        } else {
            // Left click - show clipboard history popover
            showClipboardPopover()
        }
    }
    
    private func showClipboardPopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            hidePopover()
            return
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: ClipboardPopoverView {
            self.hidePopover()
        })
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
        
        // Activate the app to ensure proper focus
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func hidePopover() {
        popover?.performClose(nil)
        popover = nil
    }
    
    private func showContextMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        let clearHistoryItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let hideItem = NSMenuItem(title: "Hide Clipboard Menu", action: #selector(hideMenuBarItem), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func clearHistory() {
        ClipboardHistoryManager.shared.clear()
    }
    
    @objc private func hideMenuBarItem() {
        removeMenuBarItem()
        // You might want to notify the main app that the clipboard menu was hidden
        UserDefaults.standard.set(false, forKey: "showClipboardMenuBar")
    }
    
    func removeMenuBarItem() {
        hidePopover()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}

// MARK: - NSPopoverDelegate
extension ClipboardMenuBarManager: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}

// MARK: - Clipboard Popover View
struct ClipboardPopoverView: View {
    @ObservedObject private var manager = ClipboardHistoryManager.shared
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Clipboard History", systemImage: "doc.on.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                
                Text("\(manager.items.count) items • Click to copy")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Content
            if manager.items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No clipboard history")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Copy something to get started")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(manager.items) { item in
                    ClipboardItemRow(item: item) {
                        manager.copyToPasteboard(item)
                        onDismiss()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Clipboard Item Row
struct ClipboardItemRow: View {
    let item: ClipboardEntry
    let onCopy: () -> Void
    
    @State private var isHovered = false
    
    private func truncated(_ text: String, maxLines: Int = 3) -> String {
        let lines = text.components(separatedBy: .newlines)
        if lines.count <= maxLines {
            return text
        }
        let truncatedLines = Array(lines.prefix(maxLines))
        return truncatedLines.joined(separator: "\n") + "..."
    }

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .center, spacing: 12) {
                // Preview
                if item.kind == .image, let img = item.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 60)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "doc.plaintext")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    if item.kind == .text, let text = item.string {
                        Text(truncated(text))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Image")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Text(timeAgo(from: item.date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Copy indicator
                if isHovered {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "now"
        }
    }
}
