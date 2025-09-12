//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @StateObject var tvm = TrayDrop.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
                    TabSelectionView()
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .animation(.smooth.delay(0.1), value: vm.notchState)
            .zIndex(2)

            if vm.notchState == .open {
                if (NSScreen.screens
                    .first(where: { $0.localizedName == coordinator.selectedScreen })?.safeAreaInsets.top ?? 0) > 0 {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .frame(width: vm.closedNotchSize.width)
                        .mask {
                            NotchShape()
                        }
                } else {
                    EmptyView()
                }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if Defaults[.showMirror] {
                        Button(action: {
                            vm.toggleCameraPreview()
                        }) {
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                .frame(width: 30, height: 30)
                                .clipShape(Capsule())
                                .overlay {
                                    Image(systemName: "web.camera")
                                        .foregroundColor(.white)
                                        .padding()
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if Defaults[.settingsIconInNotch] {
                        Button(action: {
                            SettingsWindowController.shared.showWindow()
                        }) {
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                .frame(width: 30, height: 30)
                                .clipShape(Capsule())
                                .overlay {
                                    Image(systemName: "gear")
                                        .foregroundColor(.white)
                                        .padding()
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if Defaults[.showBatteryIndicator] {
                        BoringBatteryView(
                            batteryWidth: 30,
                            isCharging: batteryModel.isCharging,
                            isInLowPowerMode: batteryModel.isInLowPowerMode,
                            isPluggedIn: batteryModel.isPluggedIn,
                            levelBattery: batteryModel.levelBattery,
                            maxCapacity: batteryModel.maxCapacity,
                            timeToFullCharge: batteryModel.timeToFullCharge,
                            isForNotification: false
                        )
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .animation(.smooth.delay(0.1), value: vm.notchState)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
