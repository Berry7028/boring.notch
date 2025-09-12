import SwiftUI

/// Simple toast to show when AirPods connect.
/// Left: image provided by the project (e.g., Assets: "airpods_pro")
/// Right: circular battery progress ring.
struct AirPodsConnectToast: View {
    var imageName: String = "airpods_pro" // Provide this asset externally
    var batteryLevel: Double              // 0.0 ... 1.0

    @EnvironmentObject var vm: BoringViewModel

    var ringColor: Color {
        switch batteryLevel {
        case 0.0..<0.2: return .red
        case 0.2..<0.5: return .yellow
        default: return Color(hue: 0.36, saturation: 0.72, brightness: 0.85)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: AirPods image (user-provided asset)
            HStack {
                Image(imageName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(
                        width: max(0, vm.effectiveClosedNotchHeight - 14),
                        height: max(0, vm.effectiveClosedNotchHeight - 14)
                    )
            }
            .frame(
                width: max(0, vm.effectiveClosedNotchHeight - 10),
                height: max(0, vm.effectiveClosedNotchHeight - 10)
            )

            // Middle separator: match existing style
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .frame(width: vm.closedNotchSize.width - 20)

            // Right: battery progress ring
            HStack {
                ProgressIndicator(
                    type: .circle,
                    progress: min(max(batteryLevel, 0), 1),
                    color: ringColor,
                    lineWidth: 4
                )
                .frame(width: 22, height: 22)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}

#Preview {
    AirPodsConnectToast(batteryLevel: 0.76)
        .environmentObject(BoringViewModel())
        .padding()
        .background(.black)
}
