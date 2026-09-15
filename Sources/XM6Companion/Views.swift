import SwiftUI
import AppKit
import XM6Core

private let accent = Color.teal

struct Card<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                if symbol == "headphones" { HeadphoneArtwork(size: 25).accessibilityHidden(true) }
                else { Image(systemName: symbol) }
                Text(title)
            }.font(.headline)
            content
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.07), lineWidth: 1))
    }
}

struct StatusPill: View {
    let text: String
    var active = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(active ? Color.teal : Color.secondary.opacity(0.6)).frame(width: 6, height: 6)
            Text(text).font(.caption.weight(.medium))
        }.padding(.horizontal, 10).padding(.vertical, 6)
            .background(active ? Color.teal.opacity(0.10) : Color.secondary.opacity(0.09), in: Capsule())
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    private let sections = [("Overview", "square.grid.2x2"), ("Sound", "waveform"), ("Headphones", "headphones"), ("Feature guide", "list.bullet.rectangle"), ("App settings", "gearshape")]
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    HeadphoneArtwork(size: 43).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("XM6").font(.title2.bold())
                        Text("STUDIO").font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(2).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 18).padding(.top, 28)
                List(selection: $model.section) {
                    ForEach(sections, id: \.0) { item in
                        Label(item.0, systemImage: item.1).padding(.vertical, 7).tag(item.0)
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 7) {
                    Label("Made for your Mac", systemImage: "desktopcomputer").font(.caption.weight(.medium))
                    Text("Local controls. No account.").font(.caption).foregroundStyle(.secondary)
                    Text("WH-1000XM6 · v1.0").font(.caption2).foregroundStyle(.tertiary)
                }.padding(20)
            }
            .navigationSplitViewColumnWidth(min: 185, ideal: 210, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    feedback
                    switch model.section {
                    case "Sound": SoundPage(model: model)
                    case "Headphones": HeadphonePage(model: model)
                    case "Feature guide": FeaturePage()
                    case "App settings": AppSettingsPage(model: model)
                    default: overview
                    }
                }.padding(30).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup {
                    Button { model.refresh() } label: { Label("Refresh controls", systemImage: "arrow.clockwise") }
                        .disabled(model.session.busy || model.session.status == .connecting)
                        .help("Read the headphones’ current settings")
                    Button { model.releaseForPhone() } label: { Label("Release for Sony app", systemImage: "iphone.and.arrow.forward") }
                        .help("Close only the settings connection; leave audio connected")
                }
            }
        }
        .onAppear { model.surfaceOpened() }
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.section).font(.system(size: 29, weight: .bold, design: .rounded))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(text: model.session.status.label, active: model.session.status == .ready)
        }
    }
    private var subtitle: String {
        switch model.section {
        case "Sound": return "Tune your listening experience."
        case "Headphones": return "Everyday settings, without reaching for your phone."
        case "Feature guide": return "What works here, and where to find everything else."
        case "App settings": return "Your listening setup, under your control."
        default: return "Your headphones and connected devices, at a glance."
        }
    }
    @ViewBuilder private var feedback: some View {
        if model.session.busy { Label("Waiting for the headphones to confirm…", systemImage: "clock").font(.callout).foregroundStyle(.secondary) }
        if let result = model.session.result {
            Label(result.message, systemImage: result.succeeded ? "checkmark.circle" : "info.circle")
                .font(.callout).foregroundStyle(result.succeeded ? Color.teal : Color.orange)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background((result.succeeded ? Color.teal : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        if let text = model.appMessage ?? model.session.notice {
            Label(text, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        if model.session.state.stale, model.session.state.lastUpdated != nil {
            HStack {
                Label("Showing last reported settings", systemImage: "clock.arrow.circlepath").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Resume controls") { model.refresh() }.buttonStyle(.bordered)
            }
        }
    }
    private var overview: some View {
        VStack(spacing: 20) {
            HStack(spacing: 28) {
                HeadphoneArtwork(size: 174, showsBackground: false).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("WH-1000XM6").font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("Your sound, within reach.").foregroundStyle(.secondary)
                    HStack {
                        Label(batteryText, systemImage: "battery.75percent").font(.title3.weight(.medium))
                        if model.session.state.battery?.isCharging == true { Text("Charging").font(.caption).foregroundStyle(accent) }
                    }
                    Text("Firmware \(model.session.state.firmware ?? "not reported")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color.teal.opacity(0.10), Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            Card(title: "Connection", symbol: "antenna.radiowaves.left.and.right") {
                HStack {
                    Picker("Headphones", selection: $model.selectedAddress) {
                        Text("Choose paired headphones").tag("")
                        ForEach(model.paired) { Text($0.name).tag($0.id) }
                    }.frame(maxWidth: 440)
                    Spacer()
                    Button("Bluetooth settings") { model.openBluetooth() }.buttonStyle(.bordered)
                }
                HStack(spacing: 12) {
                    StatusPill(text: model.selected?.connected == true ? "Bluetooth connected" : "Bluetooth not connected", active: model.selected?.connected == true)
                    StatusPill(text: model.audioReady ? "Mac audio available" : "Mac audio unavailable", active: model.audioReady)
                }
                Text("Mac output: \(model.audio.outputName)").font(.callout).foregroundStyle(.secondary)
                if model.session.status != .ready {
                    HStack {
                        Text("Pair with your Mac, enable two-device connection in Sony’s iPhone app, then refresh.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Refresh controls") { model.refresh() }.buttonStyle(.borderedProminent).disabled(model.session.status == .connecting)
                    }
                }
            }
            Card(title: "Listen where you want", symbol: "arrow.left.arrow.right") {
                HStack(spacing: 14) {
                    SourceTile(name: "This Mac", symbol: "laptopcomputer", source: model.macSource, stale: model.session.state.stale, enabled: model.session.writable && model.macSource?.isConnected == true, action: model.listenOnMac)
                    SourceTile(name: "iPhone", symbol: "iphone", source: model.phoneSource, stale: model.session.state.stale, enabled: model.session.writable && model.phoneSource?.isConnected == true, action: model.listenOnPhone)
                }
                Text("Both devices stay connected so iPhone calls can still reach your headphones. Source selection does not start paused music.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let devices = model.session.state.devices, !devices.isEmpty {
                    DisclosureGroup("Device identities") {
                        VStack(spacing: 12) {
                            Text("Identify the Mac and iPhone if they were not recognized automatically.").font(.caption).foregroundStyle(.secondary)
                            Picker("This Mac", selection: $model.macAddress) {
                                Text("Choose device").tag("")
                                ForEach(devices) { Text($0.name).tag($0.id) }
                            }
                            Picker("iPhone", selection: $model.phoneAddress) {
                                Text("Choose device").tag("")
                                ForEach(devices) { Text($0.name).tag($0.id) }
                            }
                        }.padding(.top, 10)
                    }
                    ForEach(devices) { d in
                        HStack { Text(d.name).font(.caption); Spacer(); Text(d.isConnected ? (d.isPlayback ? "Active source" : "Connected") : "Paired").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            NoiseCard(model: model)
        }
    }
    private var batteryText: String { model.session.state.battery.map { "\($0.level)%" } ?? "Battery not reported" }
}

struct SourceTile: View {
    let name: String
    let symbol: String
    let source: MultipointDevice?
    let stale: Bool
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Image(systemName: symbol).font(.title2); Spacer(); if source?.isPlayback == true && !stale { Image(systemName: "waveform").foregroundStyle(accent) } }
            Text(name).font(.headline)
            Text(stale ? "Refresh to check source" : (source?.isPlayback == true ? "Active playback source" : source?.isConnected == true ? "Connected · ready" : "Not identified / connected"))
                .font(.caption).foregroundStyle(.secondary)
            Button("Listen on \(name == "This Mac" ? "Mac" : name)", action: action).buttonStyle(.bordered).disabled(!enabled)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct NoiseCard: View {
    @ObservedObject var model: AppModel
    @State private var draftLevel = 15.0
    var body: some View {
        Card(title: "Noise control", symbol: "waveform.path") {
            HStack(spacing: 9) {
                modeButton("Noise cancelling", symbol: "waveform.slash", mode: .noiseCancelling)
                modeButton("Ambient sound", symbol: "ear", mode: .ambientSound)
                modeButton("Off", symbol: "power", mode: .off)
            }
            if let state = model.session.state.ambient {
                if state.mode == .ambientSound {
                    HStack {
                        Text("Ambient level").font(.callout)
                        Slider(value: $draftLevel, in: 0...20, step: 1) { editing in
                            if !editing, var value = model.session.state.ambient { value.level = Int(draftLevel); model.session.change(.ambient(value)) }
                        }.accessibilityLabel("Ambient sound level").disabled(!model.session.writable)
                        Text("\(Int(draftLevel))").monospacedDigit().frame(width: 25)
                    }
                    Toggle("Focus on voice", isOn: Binding(get: { state.focusOnVoice }, set: { enabled in var value = state; value.focusOnVoice = enabled; model.session.change(.ambient(value)) }))
                        .toggleStyle(.switch).disabled(!model.session.writable)
                }
                Text(model.session.state.stale ? "Last reported mode. Resume controls to edit." : "Changes are confirmed by your headphones.").font(.caption).foregroundStyle(.secondary)
            } else { UnavailableText() }
        }
        .onAppear { draftLevel = Double(model.session.state.ambient?.level ?? 15) }
        .onChange(of: model.session.state.ambient?.level) { _, value in if let value { draftLevel = Double(value) } }
        .onChange(of: model.session.busy) { _, busy in
            if !busy, let level = model.session.state.ambient?.level { draftLevel = Double(level) }
        }
    }
    private func modeButton(_ label: String, symbol: String, mode: AmbientSoundMode) -> some View {
        Button {
            guard var s = model.session.state.ambient else { return }; s.mode = mode; model.session.change(.ambient(s))
        } label: {
            VStack(spacing: 10) { Image(systemName: symbol).font(.title2); Text(label).font(.callout.weight(.medium)) }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(model.session.state.ambient?.mode == mode ? Color.teal.opacity(0.12) : Color.secondary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.session.state.ambient?.mode == mode ? Color.teal.opacity(0.6) : Color.clear))
        }.buttonStyle(.plain).disabled(!model.session.writable || model.session.state.ambient == nil)
            .accessibilityLabel(label).accessibilityAddTraits(model.session.state.ambient?.mode == mode ? .isSelected : [])
    }
}

struct UnavailableText: View {
    var text = "Not reported by the headphones. Refresh controls to check availability."
    var body: some View { Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
}

struct SoundPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 20) {
            NoiseCard(model: model)
            Card(title: "Equalizer", symbol: "slider.vertical.3") {
                if let eq = model.session.state.equalizer {
                    HStack {
                        Text("Current preset"); Spacer()
                        Text(eq.preset?.label ?? "Headphone preset \(eq.presetCode)").foregroundStyle(.secondary)
                    }
                    HStack {
                        ForEach(EqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                            Button(preset.label) { model.session.change(.equalizer(preset)) }.buttonStyle(.bordered)
                                .tint(eq.preset == preset ? .teal : .secondary)
                        }
                    }.disabled(!model.session.writable || eq.subtype != 0x04)
                    if !eq.bands.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            ForEach(Array(eq.bands.enumerated()), id: \.offset) { index, gain in
                                VStack(spacing: 6) {
                                    Capsule().fill(Color.teal.opacity(0.35)).frame(width: 12, height: CGFloat(max(8, 35 + gain * 3)))
                                    Text("\(gain > 0 ? "+" : "")\(gain)").font(.caption2).monospacedDigit()
                                }.frame(maxWidth: .infinity).accessibilityLabel("Band \(index + 1), gain \(gain)")
                            }
                        }.frame(height: 80)
                    }
                } else { UnavailableText() }
                Text("Custom curves are shown as reported. Edit custom EQ in Sony Sound Connect.").font(.caption).foregroundStyle(.secondary)
            }
            Card(title: "Listening mode", symbol: "hifispeaker.2") {
                if let mode = model.session.state.listeningMode {
                    Picker("Mode", selection: Binding(get: { mode }, set: { model.session.change(.listening($0)) })) {
                        ForEach(ListeningMode.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented).disabled(!model.session.writable)
                    if mode == .backgroundMusic, let room = model.session.state.bgmRoom {
                        Picker("Room size", selection: Binding(get: { room }, set: { model.session.change(.room($0)) })) {
                            ForEach(BGMRoomSize.allCases) { Text($0.label).tag($0) }
                        }.disabled(!model.session.writable)
                    }
                } else { UnavailableText() }
            }
            Card(title: "DSEE Extreme", symbol: "sparkles") {
                if let dsee = model.session.state.dsee {
                    Toggle("Auto", isOn: Binding(get: { dsee }, set: { model.session.change(.dsee($0)) })).toggleStyle(.switch).disabled(!model.session.writable)
                } else { UnavailableText() }
                Text("Displays the headphone setting. Processing can be inactive during calls or incompatible playback.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct HeadphonePage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "Speak-to-Chat", symbol: "bubble.left.and.text.bubble.right") {
                if let on = model.session.state.speakToChat {
                    Toggle("Pause music when you speak", isOn: Binding(get: { on }, set: { model.session.change(.speak($0)) })).toggleStyle(.switch).disabled(!model.session.writable)
                } else { UnavailableText() }
                if let config = model.session.state.chatConfig {
                    Picker("Voice sensitivity", selection: Binding(get: { config.sensitivity }, set: { model.session.change(.chatConfig(.init(sensitivity: $0, timeout: config.timeout))) })) {
                        ForEach(SpeakToChatSensitivity.allCases) { Text($0.label).tag($0) }
                    }.disabled(!model.session.writable)
                    Picker("Resume timing", selection: Binding(get: { config.timeout }, set: { model.session.change(.chatConfig(.init(sensitivity: config.sensitivity, timeout: $0))) })) {
                        ForEach(SpeakToChatTimeout.allCases) { Text($0.label).tag($0) }
                    }.disabled(!model.session.writable)
                }
            }
            Card(title: "Wearing detection", symbol: "ear.badge.waveform") {
                if let on = model.session.state.wearingPause {
                    Toggle("Pause when headphones are removed", isOn: Binding(get: { on }, set: { model.session.change(.wearing($0)) })).toggleStyle(.switch).disabled(!model.session.writable)
                } else { UnavailableText() }
            }
            Card(title: "Automatic power-off", symbol: "power") {
                if let mode = model.session.state.powerOff {
                    Picker("Turn off automatically", selection: Binding(get: { mode }, set: { model.session.change(.powerOff($0)) })) {
                        ForEach(AutomaticPowerOffMode.allCases) { Text($0.label).tag($0) }
                    }.disabled(!model.session.writable)
                } else { UnavailableText() }
            }
            Card(title: "More headphone settings", symbol: "iphone") {
                Text("Firmware updates, touch gestures, voice guidance, and phone-based automation are available in Sony Sound Connect. The feature guide lists every XM6 setting and where to manage it.").foregroundStyle(.secondary)
                Button("Open feature guide") { model.section = "Feature guide" }.buttonStyle(.bordered)
            }
        }
    }
}

struct FeaturePage: View {
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(FeatureCatalog.items.count) Sony features accounted for").font(.headline)
            Text("Source switching and core settings were checked on WH-1000XM6 firmware 3.1.5. The included verification report lists the tested controls and remaining checks. A control becomes editable only after the headset reports it.").font(.callout).foregroundStyle(.secondary)
            TextField("Find a feature", text: $search).textFieldStyle(.roundedBorder)
            ForEach(FeatureCatalog.items.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search) }) { feature in
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: feature.mac ? "desktopcomputer" : "iphone").foregroundStyle(feature.mac ? Color.teal : Color.secondary).frame(width: 24).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(feature.name).font(.callout.weight(.semibold)); Spacer(); Text(feature.mac ? "Mac control" : "Sony app / system").font(.caption).foregroundStyle(.secondary) }
                        Text(feature.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 12))
            }
            Link("Sony WH-1000XM6 feature reference ↗", destination: URL(string: FeatureCatalog.source)!).font(.caption)
            Button("Open verification report") {
                if let url = Bundle.main.resourceURL?.appendingPathComponent("Verification.md") { NSWorkspace.shared.open(url) }
            }.buttonStyle(.bordered)
        }
    }
}

struct AppSettingsPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 20) {
            Card(title: "General", symbol: "gearshape") {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin)).toggleStyle(.switch)
                Text("Close the window to keep quick controls in the menu bar. Quit from the menu bar or with ⌘Q.").font(.callout).foregroundStyle(.secondary)
                Text("Controls release after 30 seconds without an action. This leaves the headphones’ audio connections intact.").font(.callout).foregroundStyle(.secondary)
                Button("Release controls for Sony app") { model.releaseForPhone() }.buttonStyle(.bordered)
            }
            Card(title: "Connection help", symbol: "questionmark.circle") {
                Text("1. Pair WH-1000XM6 with your Mac and iPhone.\n2. Enable “Connect to 2 devices simultaneously” in Sony Sound Connect.\n3. Select WH-1000XM6 as the Mac’s audio output.\n4. Allow Bluetooth access for XM6 Studio.\n5. Close Sony’s app if the Mac controls cannot open.").font(.callout).lineSpacing(7)
                HStack { Button("Bluetooth settings", action: model.openBluetooth); Button("Bluetooth permission", action: model.openPrivacy) }.buttonStyle(.bordered)
                Text("Phone notifications may trigger source switching. Lower notification sounds on iPhone if needed. This app keeps the iPhone connected for calls and does not continuously force a source.").font(.caption).foregroundStyle(.secondary)
            }
            Card(title: "Diagnostics", symbol: "doc.text.magnifyingglass") {
                Text("A local, bounded event log records connection and source changes. Exports remove device names and Bluetooth addresses. Audio and raw Bluetooth packets are never recorded.").font(.callout).foregroundStyle(.secondary)
                Button("Export diagnostics…", action: model.exportDiagnostics).buttonStyle(.bordered)
            }
            Card(title: "About XM6 Studio", symbol: "headphones") {
                Text("Version 1.0.1 · macOS 15+ · Apple Silicon").font(.callout)
                Text("Independent software for personal use. Built with SwiftUI, IOBluetooth, and Core Audio. Protocol work adapted from xm6-control and SonyHeadphonesClient. Unaffiliated with Sony.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Link("Protocol credits", destination: URL(string: "https://github.com/ruimartins23/xm6-control")!)
                    Button("View licenses") {
                        if let url = Bundle.main.resourceURL?.appendingPathComponent("THIRD_PARTY.md") { NSWorkspace.shared.open(url) }
                    }
                }.font(.caption)
            }
        }
    }
}

struct QuickPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HeadphoneArtwork(size: 36).accessibilityHidden(true)
                Text("XM6 Studio").font(.headline)
                Spacer()
                Text(model.session.state.battery.map { "\($0.level)%" } ?? "—").font(.callout.monospacedDigit())
            }
            StatusPill(text: model.session.status.label, active: model.session.status == .ready)
            if let result = model.session.result { Text(result.message).font(.caption).foregroundStyle(result.succeeded ? Color.teal : Color.orange).fixedSize(horizontal: false, vertical: true) }
            if let notice = model.session.notice { Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button("Listen on Mac", action: model.listenOnMac).disabled(!model.session.writable || model.macSource?.isConnected != true)
                Button("Listen on iPhone", action: model.listenOnPhone).disabled(!model.session.writable || model.phoneSource?.isConnected != true)
            }.buttonStyle(.bordered)
            HStack {
                ForEach([AmbientSoundMode.noiseCancelling, .ambientSound, .off], id: \.self) { mode in
                    Button(mode == .noiseCancelling ? "NC" : mode == .ambientSound ? "Ambient" : "Off") {
                        guard var s = model.session.state.ambient else { return }; s.mode = mode; model.session.change(.ambient(s))
                    }.tint(model.session.state.ambient?.mode == mode ? .teal : .secondary)
                }
            }.buttonStyle(.bordered).disabled(!model.session.writable || model.session.state.ambient == nil)
            if model.session.state.stale { Text("Last reported values · Refresh to edit").font(.caption).foregroundStyle(.secondary) }
            Button("Refresh controls", action: model.refresh).disabled(model.session.busy || model.session.status == .connecting)
            Button("Release controls for Sony app") { model.releaseForPhone() }
            Divider()
            HStack {
                Button("Open app") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { model.session.release(); NSApp.terminate(nil) }
            }
        }.padding(20).frame(width: 360).onAppear { model.surfaceOpened() }
    }
}
