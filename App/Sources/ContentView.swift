import SwiftUI
import Foundation
import ProtopandaControllerCore

struct ContentView: View {
    @ObservedObject var viewModel: ControllerViewModel
    @ObservedObject var bleController: BLEPeripheralController
    @ObservedObject var motionController: MotionController

    @State private var showSettings = false
    @State private var showQuitConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider().background(Color.white.opacity(0.12))

            GeometryReader { geometry in
                ZStack {
                    ForEach(DPadLayout.regions, id: \.button) { button, unitRect in
                        DPadButtonView(
                            label: DPadLayout.labelText(for: button),
                            isPressed: viewModel.pressedButtons.contains(button)
                        )
                        .frame(
                            width: unitRect.width * geometry.size.width,
                            height: unitRect.height * geometry.size.height
                        )
                        .position(
                            x: (unitRect.minX + unitRect.width / 2) * geometry.size.width,
                            y: (unitRect.minY + unitRect.height / 2) * geometry.size.height
                        )
                    }
                    MultiTouchPadView { pressed in
                        viewModel.setPressedButtons(pressed)
                    }
                }
            }
            .padding(24)

            imuReadout
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("action.quit_app_title", isPresented: $showQuitConfirmation) {
            Button("action.cancel", role: .cancel) {}
            Button("action.quit", role: .destructive) {
                viewModel.quitApp()
            }
        } message: {
            Text("action.quit_app_message")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            statusText
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            Button(role: .destructive) {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "power")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var statusColor: Color {
        switch bleController.status {
        case .connected:
            return .green
        case .connectedAwaitingID, .advertising:
            return .yellow
        case .bluetoothUnavailable, .advertisingFailed:
            return .orange
        case .idle:
            return .gray
        }
    }

    private var statusText: Text {
        switch bleController.status {
        case .bluetoothUnavailable(let reason):
            switch reason {
            case .poweredOff:
                return Text("status.bluetooth_off")
            case .unauthorized:
                return Text("status.bluetooth_unauthorized")
            case .unsupported:
                return Text("status.bluetooth_unsupported")
            }
        case .idle:
            return Text("status.idle")
        case .advertising:
            return Text("status.advertising")
        case .connectedAwaitingID:
            return Text("status.connected_awaiting_id")
        case .connected(let id):
            return Text(String(format: NSLocalizedString("status.connected_id", comment: ""), id))
        case .advertisingFailed(let reason):
            switch reason {
            case .serviceRegistrationFailed:
                return Text("status.service_registration_failed")
            case .systemError(let message):
                return Text(String(format: NSLocalizedString("status.advertising_failed", comment: ""), message))
            }
        }
    }

    private var imuReadout: some View {
        VStack(spacing: 2) {
            Text(String(
                format: "Acc  X:%.2f  Y:%.2f  Z:%.2f m/s²",
                motionController.displayAccel.x,
                motionController.displayAccel.y,
                motionController.displayAccel.z
            ))
            Text(String(
                format: "Gyro X:%.2f  Y:%.2f  Z:%.2f °/s",
                motionController.displayGyro.x,
                motionController.displayGyro.y,
                motionController.displayGyro.z
            ))
            if !motionController.isAccelerometerAvailable || !motionController.isGyroscopeAvailable {
                Text("imu.sensors_unavailable")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

private struct DPadButtonView: View {
    let label: String
    let isPressed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isPressed ? Color.accentColor : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .overlay(
                Text(label)
                    .font(.headline)
                    .foregroundStyle(isPressed ? Color.black : Color.white)
            )
            .allowsHitTesting(false) // MultiTouchPadView owns all touch handling
    }
}
