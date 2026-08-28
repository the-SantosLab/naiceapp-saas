import Foundation
import SwiftUI
import HomeKit

// MARK: - HomeKit Bridge

/// Wraps HMHomeManager to discover and control HomeKit accessories.
/// Apple's HomeKit framework requires the `com.apple.developer.homekit`
/// entitlement and `NSHomeKitUsageDescription` in Info.plist.
@MainActor
final class NAHomeKitBridge: NSObject, ObservableObject, HMHomeManagerDelegate {
    static let shared = NAHomeKitBridge()

    private let homeManager = HMHomeManager()
    private var homes: [HMHome] { homeManager.homes }

    @Published var isReady = false
    @Published var lastError: String?

    private override init() {
        super.init()
        homeManager.delegate = self
    }

    // MARK: HMHomeManagerDelegate

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            isReady = true
            objectWillChange.send()
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in
            isReady = true
        }
    }

    // MARK: Accessory Discovery

    /// Returns a list of all HomeKit accessories across all homes as NAHomeDevice models.
    var discoveredDevices: [NAHomeDevice] {
        guard isReady else { return [] }
        return homes.flatMap { home in
            home.accessories.map { accessory in
                let (isOn, brightness, temp) = accessoryState(accessory)
                return NAHomeDevice(
                    name: accessory.name,
                    type: deviceType(for: accessory),
                    isOn: isOn,
                    brightness: brightness,
                    temperature: temp,
                    room: home.name,
                    bridge: .homekit
                )
            }
        }
    }

    // MARK: Control

    func turnOn(_ accessory: HMAccessory) async {
        await setPower(accessory, on: true)
    }

    func turnOff(_ accessory: HMAccessory) async {
        await setPower(accessory, on: false)
    }

    func setBrightness(_ accessory: HMAccessory, _ value: Double) async {
        let intVal = Int(value)
        for service in accessory.services {
            for char in service.characteristics where char.characteristicType == HMCharacteristicTypeBrightness {
                do {
                    try await char.writeValue(intVal)
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    func setTemperature(_ accessory: HMAccessory, _ celsius: Double) async {
        for service in accessory.services {
            for char in service.characteristics where char.characteristicType == HMCharacteristicTypeTargetTemperature {
                do {
                    try await char.writeValue(celsius)
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: Helpers

    /// Looks up an HMAccessory by its name and home name.
    func accessory(named name: String, in homeName: String) -> HMAccessory? {
        for home in homes where home.name == homeName {
            if let accessory = home.accessories.first(where: { $0.name == name }) {
                return accessory
            }
        }
        return nil
    }

    private func setPower(_ accessory: HMAccessory, on: Bool) async {
        for service in accessory.services {
            for char in service.characteristics where char.characteristicType == HMCharacteristicTypePowerState {
                do {
                    try await char.writeValue(on)
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    private func accessoryState(_ accessory: HMAccessory) -> (isOn: Bool, brightness: Double, temperature: Double) {
        var isOn = false
        var brightness: Double = 100
        var temp: Double = 20

        for service in accessory.services {
            for char in service.characteristics {
                switch char.characteristicType {
                case HMCharacteristicTypePowerState:
                    isOn = (char.value as? Bool) ?? false
                case HMCharacteristicTypeBrightness:
                    brightness = Double((char.value as? Int) ?? 100)
                case HMCharacteristicTypeCurrentTemperature:
                    temp = (char.value as? Double) ?? 20
                default:
                    break
                }
            }
        }
        return (isOn, brightness, temp)
    }

    private func deviceType(for accessory: HMAccessory) -> DeviceType {
        for service in accessory.services {
            if service.serviceType == HMServiceTypeLightbulb { return .light }
            if service.serviceType == HMServiceTypeThermostat { return .thermostat }
            if service.serviceType == HMServiceTypeOutlet { return .plug }
            if service.serviceType == HMServiceTypeWindowCovering { return .blind }
            if service.serviceType == HMServiceTypeTemperatureSensor { return .sensor }
        }
        return .light
    }
}

// MARK: - NAHomeDevice with HomeKit accessory reference

// MARK: - Smart Home Device
struct NAHomeDevice: Identifiable, Codable {
    var id = UUID().uuidString
    let name: String
    var type: DeviceType
    var isOn: Bool = false
    var brightness: Double = 100 // 0-100
    var color: String = "white" // white, warm, cold, custom
    var temperature: Double = 20.0 // °C für Thermostate
    var room: String = ""
    var bridge: DeviceBridge = .hue
    var isReachable: Bool = true
}

enum DeviceType: String, Codable, CaseIterable {
    case light, thermostat, plug, blind, sensor

    var icon: String {
        switch self {
        case .light: return "lightbulb.fill"
        case .thermostat: return "thermometer"
        case .plug: return "poweroutlet.type.b"
        case .blind: return "blinds.horizontal.open"
        case .sensor: return "sensor.fill"
        }
    }
}

enum DeviceBridge: String, Codable {
    case hue, homekit, mock
}

// MARK: - Smart Home Service
@MainActor
class NASmartHomeService: ObservableObject {
    static let shared = NASmartHomeService()

    @Published var devices: [NAHomeDevice] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let devicesKey = "naice_home_devices"
    private let serverURL = "https://health.santoslab.de/api/smarthome"

    init() {
        loadDevices()
        if devices.isEmpty { setupDefaultDevices() }
        // HomeKit: sync discovered devices on next run loop
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s warten bis HomeKit ready
            syncHomeKitDevices()
        }
    }

    // MARK: HomeKit Sync

    /// Discovers HomeKit accessories and merges them into the device list.
    /// Existing devices (matched by name + room) are preserved; new ones are added.
    func syncHomeKitDevices() {
        let bridge = NAHomeKitBridge.shared
        guard bridge.isReady else { return }
        let hkDevices = bridge.discoveredDevices
        guard !hkDevices.isEmpty else { return }

        for hkDevice in hkDevices {
            if !devices.contains(where: { $0.name == hkDevice.name && $0.room == hkDevice.room }) {
                devices.append(hkDevice)
            }
        }
        saveDevices()
    }

    private func setupDefaultDevices() {
        devices = [
            NAHomeDevice(name: "Wohnzimmer Licht", type: .light, isOn: false, room: "Wohnzimmer", bridge: .hue),
            NAHomeDevice(name: "Schlafzimmer Licht", type: .light, isOn: false, room: "Schlafzimmer", bridge: .hue),
            NAHomeDevice(name: "Thermostat Wohnzimmer", type: .thermostat, isOn: true, temperature: 21, room: "Wohnzimmer", bridge: .homekit),
            NAHomeDevice(name: "Thermostat Schlafzimmer", type: .thermostat, isOn: true, temperature: 18, room: "Schlafzimmer", bridge: .homekit),
            NAHomeDevice(name: "Küche Steckdose", type: .plug, isOn: false, room: "Küche", bridge: .mock),
        ]
        saveDevices()
    }

    // MARK: Control
    func toggle(_ device: NAHomeDevice) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].isOn.toggle()
        saveDevices()
        sendCommand(devices[idx])
    }

    func setBrightness(_ device: NAHomeDevice, _ value: Double) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].brightness = value
        if value > 0 { devices[idx].isOn = true }
        saveDevices()
        sendCommand(devices[idx])
    }

    func setTemperature(_ device: NAHomeDevice, _ value: Double) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].temperature = value
        saveDevices()
        sendCommand(devices[idx])
    }

    // MARK: Scenes
    func goodMorning() {
        for i in devices.indices {
            if devices[i].type == .light && devices[i].room == "Wohnzimmer" {
                devices[i].isOn = true; devices[i].brightness = 60
            }
            if devices[i].type == .thermostat {
                devices[i].temperature = 21
            }
        }
        saveDevices()
        sendBatch()
    }

    func goodNight() {
        for i in devices.indices {
            if devices[i].type == .light { devices[i].isOn = false }
            if devices[i].type == .thermostat { devices[i].temperature = 17 }
        }
        saveDevices()
        sendBatch()
    }

    func leaveHome() {
        for i in devices.indices {
            if devices[i].type == .light { devices[i].isOn = false }
            if devices[i].type == .thermostat { devices[i].temperature = 16 }
            if devices[i].type == .plug { devices[i].isOn = false }
        }
        saveDevices()
        sendBatch()
    }

    // MARK: Server Sync + HomeKit Control
    private func sendCommand(_ device: NAHomeDevice) {
        // HomeKit: control directly via the HomeKit bridge
        if device.bridge == .homekit {
            let bridge = NAHomeKitBridge.shared
            guard bridge.isReady else { return }
            guard let accessory = bridge.accessory(named: device.name, in: device.room) else { return }

            Task {
                switch device.type {
                case .light:
                    if device.isOn {
                        await bridge.turnOn(accessory)
                        if device.brightness < 100 {
                            await bridge.setBrightness(accessory, device.brightness)
                        }
                    } else {
                        await bridge.turnOff(accessory)
                    }
                case .thermostat:
                    await bridge.setTemperature(accessory, device.temperature)
                case .plug:
                    if device.isOn { await bridge.turnOn(accessory) }
                    else { await bridge.turnOff(accessory) }
                default:
                    break
                }
            }
            return
        }

        // Non-HomeKit: send to server bridge
        guard let url = URL(string: "\(serverURL)/\(device.bridge.rawValue)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device": device.id, "name": device.name, "type": device.type.rawValue,
            "isOn": device.isOn, "brightness": device.brightness, "temperature": device.temperature
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    private func sendBatch() {
        // HomeKit: control each HomeKit device directly
        let homeKitDevices = devices.filter { $0.bridge == .homekit }
        if !homeKitDevices.isEmpty {
            let bridge = NAHomeKitBridge.shared
            guard bridge.isReady else { return }
            Task {
                for device in homeKitDevices {
                    guard let accessory = bridge.accessory(named: device.name, in: device.room) else { continue }
                    if device.isOn {
                        await bridge.turnOn(accessory)
                        if device.type == .thermostat {
                            await bridge.setTemperature(accessory, device.temperature)
                        } else if device.type == .light, device.brightness < 100 {
                            await bridge.setBrightness(accessory, device.brightness)
                        }
                    } else {
                        await bridge.turnOff(accessory)
                    }
                }
            }
        }

        // Also send to server (non-HomeKit devices still need server sync)
        let nonHomeKitDevices = devices.filter { $0.bridge != .homekit }
        guard !nonHomeKitDevices.isEmpty else { return }
        guard let url = URL(string: "\(serverURL)/batch") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(nonHomeKitDevices)
        URLSession.shared.dataTask(with: req).resume()
    }

    private func saveDevices() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
    }

    private func loadDevices() {
        guard let data = UserDefaults.standard.data(forKey: devicesKey),
              let decoded = try? JSONDecoder().decode([NAHomeDevice].self, from: data) else { return }
        devices = decoded
    }
}

// MARK: - Smart Home View
struct NASmartHomeView: View {
    @ObservedObject private var home = NASmartHomeService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Home")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(home.devices.filter { $0.isOn }.count)/\(home.devices.count) Gerate aktiv")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Scenes
                sectionHeader("Szenen")
                HStack(spacing: 10) {
                    sceneButton("🌅", "Guten Morgen", .ncAmber) { home.goodMorning() }
                    sceneButton("🌙", "Gute Nacht", .ncPurple) { home.goodNight() }
                    sceneButton("🚪", "Verlassen", .ncRose) { home.leaveHome() }
                }
                .padding(.horizontal, 16)

                // Rooms
                let rooms = Array(Set(home.devices.map { $0.room })).sorted()
                ForEach(rooms, id: \.self) { room in
                    roomSection(room)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "homekit")
                .font(.caption)
                .foregroundColor(.ncCyan)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }

    private func sceneButton(_ emoji: String, _ label: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.title2)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func roomSection(_ room: String) -> some View {
        let roomDevices = home.devices.filter { $0.room == room }
        return VStack(alignment: .leading, spacing: 10) {
            Text(room)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            VStack(spacing: 6) {
                ForEach(roomDevices) { device in
                    deviceRow(device)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private func deviceRow(_ device: NAHomeDevice) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(device.isOn ? Color.ncAmber.opacity(0.12) : Color.gray.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: device.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(device.isOn ? .ncAmber : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                if device.type == .thermostat {
                    Text("\(Int(device.temperature))°C")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if device.type == .light {
                    Text(device.isOn ? "\(Int(device.brightness))%" : "Aus")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if device.type == .light && device.isOn {
                Slider(value: Binding(
                    get: { device.brightness },
                    set: { home.setBrightness(device, $0) }
                ), in: 1...100)
                .frame(width: 80)
                .tint(.ncAmber)
            }

            if device.type == .thermostat {
                HStack(spacing: 4) {
                    Button { home.setTemperature(device, device.temperature - 1) } label: {
                        Image(systemName: "minus.circle").foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    Button { home.setTemperature(device, device.temperature + 1) } label: {
                        Image(systemName: "plus.circle").foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle("", isOn: Binding(
                get: { device.isOn },
                set: { _ in home.toggle(device) }
            ))
            .labelsHidden()
            .tint(.ncAmber)
            .scaleEffect(0.7)
        }
        .padding(10)
        .background(Color(red: 0.03, green: 0.03, blue: 0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}