import SwiftUI

/// Banner shown when macOS is locked or just unlocked.
/// Left: status text. Right: lock/unlock icon. Matches Notch toast style.
struct LockStatusBanner: View {
    var isLocked: Bool

    @EnvironmentObject var vm: BoringViewModel

    private var text: String {
        isLocked ? "ロック中" : "ロック解除"
    }

    private var iconName: String { isLocked ? "lock.fill" : "lock.open.fill" }
    private var iconColor: Color { isLocked ? .yellow : .green }

    var body: some View {
        HStack(spacing: 0) {
            // Left: text
            HStack {
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(
                width: max(0, vm.effectiveClosedNotchHeight * 2),
                height: max(0, vm.effectiveClosedNotchHeight - 10),
                alignment: .leading
            )

            // Middle separator: same look as other toasts
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .frame(width: vm.closedNotchSize.width - 20)

            // Right: icon
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isLocked ? 1.0 : 1.15)
                    .rotationEffect(.degrees(isLocked ? 0 : 8))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isLocked)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}

#Preview {
    LockStatusBanner(isLocked: false)
        .environmentObject(BoringViewModel())
        .padding()
        .background(.black)
}
