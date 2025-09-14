import SwiftUI
import AppKit

// MARK: - Inline Clipboard Panel

struct NotchClipboardView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var clipboard = ClipboardHistoryManager.shared

    private let cardSize = CGSize(width: 240, height: 135)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 10)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if clipboard.items.isEmpty {
            ClipsEmptyStateView()
                .frame(height: cardSize.height)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 18) {
                    ForEach(clipboard.items.prefix(12)) { item in
                        ClipboardCard(item: item) {
                            clipboard.copyToPasteboard(item)
                        }
                        .frame(width: cardSize.width, height: cardSize.height)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 4)
            }
            .scrollIndicators(.never)
            .padding(.leading, 2)
        }
    }
}

// MARK: - Card

private struct ClipboardCard: View {
    let item: ClipboardEntry
    let onCopy: () -> Void

    @State private var hovered = false
    @State private var copied = false

    var body: some View {
        Button(action: {
            onCopy()
            performLightHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                copied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.25)) { copied = false }
            }
        }) {
            ZStack(alignment: .topLeading) {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.08 : 0.06))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(hovered ? 0.20 : 0.10), lineWidth: 1)

                // Copy feedback layer (soft green glow)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.green.opacity(0.25),
                            Color.green.opacity(0.15)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .opacity(copied ? 1 : 0)
                    .blendMode(.plusLighter)

                VStack(alignment: .leading, spacing: 10) {
                    preview
                    Spacer(minLength: 0)
                    footer
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .overlay(alignment: .topTrailing) {
            // Hover hint or copied checkmark
            Group {
                if copied {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.green)
                        .imageScale(.large)
                        .transition(.scale.combined(with: .opacity))
                } else if hovered {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)
                        .transition(.opacity)
                }
            }
            .padding(8)
        }
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let img = item.image {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 70)
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 70)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            } else {
                placeholder
            }
        case .text:
            if let s = item.string {
                Text(truncated(s))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isURL(s) ? Color.accentColor : Color.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.06))
            .frame(height: 60)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let bundle = item.bundleIdentifier {
                AppIcon(for: bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            Text(item.appName ?? "")
                .lineLimit(1)
            Text("•")
            Text(dateString(item.date))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func truncated(_ s: String, max: Int = 100) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }

    private func isURL(_ s: String) -> Bool {
        if let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return url.scheme != nil }
        return false
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm dd.MM.yyyy"
        return f.string(from: date)
    }
}

// MARK: - Haptics
private func performLightHaptic() {
    #if canImport(AppKit)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
}

// MARK: - Empty

private struct ClipsEmptyStateView: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                Text("No recent items")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// (Filters removed per design feedback)
