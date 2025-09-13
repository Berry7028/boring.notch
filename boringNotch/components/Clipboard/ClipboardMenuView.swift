import SwiftUI

struct ClipboardMenuView: View {
    @ObservedObject var manager = ClipboardHistoryManager.shared

    private func truncated(_ text: String, max: Int = 80) -> String {
        if text.count <= max { return text }
        let prefix = text.prefix(max)
        return String(prefix) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if manager.items.isEmpty {
                emptyState
            } else {
                itemsList
                clearButton
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clipboard History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text("Select an item to copy it back to your clipboard.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var itemsList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(manager.items.prefix(10))) { entry in
                    Button(action: {
                        manager.copyToPasteboard(entry)
                    }) {
                        ZStack {
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            HStack(spacing: 10) {
                                if entry.kind == .image, let img = entry.image {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 42, height: 32)
                                        .cornerRadius(6)
                                }
                                if entry.kind == .text, let s = entry.string {
                                    Text(truncated(s))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                } else if entry.kind == .image {
                                    Text("Image")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                        }
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 360)
    }

    private var clearButton: some View {
        Button(action: { manager.clear() }) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Text("Clear History")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Text("No recent items")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

#if DEBUG
struct ClipboardMenuView_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardMenuView()
    }
}
#endif
