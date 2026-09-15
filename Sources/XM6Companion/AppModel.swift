import AppKit
import Combine
import ServiceManagement
import XM6Core

@MainActor final class AppModel: ObservableObject {
    let transport: BluetoothTransport
    let session: ControlSession
    let audio = AudioRouter()
    @Published var paired: [PairedHeadphone] = []
    @Published var selectedAddress: String {
        didSet {
            guard oldValue != selectedAddress else { return }
            UserDefaults.standard.set(selectedAddress, forKey: "headphone")
            session.clearSelection(); loadRoles(); audio.refresh()
        }
    }
    @Published var macAddress = "" { didSet { saveRoles() } }
    @Published var phoneAddress = "" { didSet { saveRoles() } }
    @Published var section = "Overview"
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var appMessage: String?
    private var localAddress: String?
    private var wantedRefresh = false
    private var subscriptions = Set<AnyCancellable>()
    private var loadingRoles = false
    private var wakeTokens: [NSObjectProtocol] = []
    var selected: PairedHeadphone? { paired.first { $0.id == selectedAddress } }
    var headphoneOutput: AudioOutput? { audio.headphoneOutput(address: selectedAddress, name: selected?.name ?? "WH-1000XM6") }
    var audioReady: Bool { headphoneOutput != nil }
    var audioSelected: Bool { headphoneOutput.map { $0.id == audio.selected } ?? false }
    var macSource: MultipointDevice? { session.state.devices?.first { normalizedAddress($0.id) == normalizedAddress(macAddress) } }
    var phoneSource: MultipointDevice? { session.state.devices?.first { normalizedAddress($0.id) == normalizedAddress(phoneAddress) } }
    var connectedSources: [MultipointDevice] { session.state.devices?.filter(\.isConnected) ?? [] }

    init() {
        transport = BluetoothTransport(); session = ControlSession(transport: transport)
        selectedAddress = UserDefaults.standard.string(forKey: "headphone") ?? ""
        loadRoles()
        session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        audio.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        session.$state.sink { [weak self] state in
            DispatchQueue.main.async { self?.identifySources(state) }
        }.store(in: &subscriptions)
        transport.worker.onInventory = { [weak self] devices, local in
            DispatchQueue.main.async { self?.inventory(devices, local: local) }
        }
        audio.onChange = { [weak self] message in self?.session.diagnostics.record("audio-route", message) }
        transport.worker.startInventory()
        let center = NSWorkspace.shared.notificationCenter
        wakeTokens.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.session.release(); self?.session.diagnostics.record("system", "Mac sleeping") }
        })
        wakeTokens.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.session.diagnostics.record("system", "Mac woke; waiting for user to resume controls")
                self.audio.refresh(); self.transport.worker.execute { [weak self] in self?.transport.worker.scan() }
            }
        })
    }
    private func inventory(_ devices: [PairedHeadphone], local: String?) {
        let previous = selected?.connected
        paired = devices; localAddress = local
        if selectedAddress.isEmpty, let xm6 = devices.first(where: { $0.name.localizedCaseInsensitiveContains("WH-1000XM6") }) { selectedAddress = xm6.id }
        if previous == true && selected?.connected == false { session.audioDisconnected() }
        if previous == false && selected?.connected == true { session.diagnostics.record("bluetooth", "macOS reports headphones connected") }
        if wantedRefresh, let selected {
            wantedRefresh = false
            if selected.connected { appMessage = nil; session.resume(address: selected.id) }
            else { appMessage = "Connect WH-1000XM6 in macOS Bluetooth settings first, then refresh." }
        }
    }
    func refresh() {
        appMessage = nil; audio.refresh()
        if let selected, selected.connected { session.resume(address: selected.id) }
        else {
            wantedRefresh = true
            transport.worker.execute { [weak self] in self?.transport.worker.scan() }
            appMessage = "Pair and connect WH-1000XM6 in Bluetooth settings, then choose it above."
        }
    }
    func surfaceOpened() {
        guard !session.releasedForPhone, session.status != .connecting, !session.busy else { return }
        if session.status != .ready { refresh() }
    }
    func releaseForPhone() {
        wantedRefresh = false
        session.release(forPhone: true)
    }
    private func roleKey(_ suffix: String) -> String { "\(selectedAddress).\(suffix)" }
    private func loadRoles() {
        loadingRoles = true
        macAddress = UserDefaults.standard.string(forKey: roleKey("mac")) ?? ""
        phoneAddress = UserDefaults.standard.string(forKey: roleKey("phone")) ?? ""
        loadingRoles = false
    }
    private func saveRoles() {
        guard !loadingRoles, !selectedAddress.isEmpty else { return }
        UserDefaults.standard.set(macAddress, forKey: roleKey("mac"))
        UserDefaults.standard.set(phoneAddress, forKey: roleKey("phone"))
    }
    private func identifySources(_ state: HeadphoneState) {
        guard let devices = state.devices else { return }
        if macAddress.isEmpty, let localAddress, let match = devices.first(where: { normalizedAddress($0.id) == normalizedAddress(localAddress) }) { macAddress = match.id }
        let phones = devices.filter { $0.name.localizedCaseInsensitiveContains("iphone") }
        if phoneAddress.isEmpty, phones.count == 1 { phoneAddress = phones[0].id }
    }
    func listenOnMac() {
        guard session.writable, let source = macSource, source.isConnected else {
            session.reject("Refresh controls and identify this Mac in Device identities first."); return
        }
        guard normalizedAddress(macAddress) != normalizedAddress(phoneAddress) else {
            session.reject("Assign different devices to Mac and iPhone."); return
        }
        guard let output = headphoneOutput, audio.select(output) else {
            session.reject("macOS could not select the headphones as audio output. Open Sound settings and select WH-1000XM6."); return
        }
        session.diagnostics.record("audio-route", "User selected headphones as Mac output")
        session.change(.source(source.id))
    }
    func listenOnPhone() {
        guard session.writable, let source = phoneSource, source.isConnected,
              normalizedAddress(phoneAddress) != normalizedAddress(macAddress) else {
            session.reject("Refresh controls and identify your connected iPhone in Device identities first."); return
        }
        session.change(.source(source.id))
    }
    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if value && !loginEnabled { appMessage = "Approve XM6 Studio under System Settings → General → Login Items." }
        } catch { appMessage = "Launch at login could not be changed: \(error.localizedDescription)"; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    func openBluetooth() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!) }
    func openPrivacy() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!) }
    func diagnosticsText() -> String {
        let names = paired.map(\.name) + (session.state.devices?.map(\.name) ?? []) + [Host.current().localizedName ?? "", NSUserName(), NSFullUserName(), NSHomeDirectory()]
        return "App: XM6 Studio 1.0.1\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nFirmware: \(session.state.firmware ?? "Not reported")\nControl: \(session.status.label)\nMac audio available: \(audioReady)\nMac output selected: \(audioSelected)\nNoise state: \(String(describing: session.state.ambient))\n\n" + session.diagnostics.report(redacting: names)
    }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "XM6-Diagnostics.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try diagnosticsText().write(to: url, atomically: true, encoding: .utf8); appMessage = "Diagnostics exported." }
        catch { appMessage = "Could not export diagnostics: \(error.localizedDescription)" }
    }
}
