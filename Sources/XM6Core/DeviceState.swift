import Foundation

public enum ProtocolVersion: Equatable, Sendable { case unknown, v1, v2 }

public struct PairedHeadphone: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let connected: Bool
    public init(id: String, name: String, connected: Bool) {
        self.id = id; self.name = name; self.connected = connected
    }
}

public enum ControlStatus: Equatable {
    case idle, connecting, ready, released, failed(String)
    public var label: String {
        switch self {
        case .idle: return "Controls sleeping"
        case .connecting: return "Opening controls…"
        case .ready: return "Controls ready"
        case .released: return "Released for Sony app"
        case .failed: return "Controls unavailable"
        }
    }
}

public struct HeadphoneState: Equatable {
    public var model: String?
    public var firmware: String?
    public var battery: BatteryStatus?
    public var ambient: AmbientSoundState?
    public var equalizer: EqualizerState?
    public var speakToChat: Bool?
    public var chatConfig: SpeakToChatConfigState?
    public var powerOff: AutomaticPowerOffMode?
    public var wearingPause: Bool?
    public var bgmEnabled: Bool?
    public var bgmRoom: BGMRoomSize?
    public var bgmSubtype: UInt8?
    public var cinema: Bool?
    public var dsee: Bool?
    public var devices: [MultipointDevice]?
    public var lastUpdated: Date?
    public var stale = true
    public init() {}
    public var listeningMode: ListeningMode? {
        guard let bgmEnabled, let cinema else { return nil }
        if bgmEnabled && cinema { return nil }
        return bgmEnabled ? .backgroundMusic : (cinema ? .cinema : .standard)
    }
    public var confirmedXM6: Bool { model?.uppercased() == "WH-1000XM6" }
}

public enum CommandResult: Equatable {
    case confirmed(String), failed(String), unconfirmed(String)
    public var message: String {
        switch self { case .confirmed(let s), .failed(let s), .unconfirmed(let s): return s }
    }
    public var succeeded: Bool { if case .confirmed = self { return true }; return false }
}

public enum HeadphoneChange {
    case ambient(AmbientSoundState), equalizer(EqualizerPreset), speak(Bool)
    case chatConfig(SpeakToChatConfigState), powerOff(AutomaticPowerOffMode), wearing(Bool)
    case listening(ListeningMode), room(BGMRoomSize), dsee(Bool), source(String)

    public var label: String {
        switch self {
        case .ambient: return "Noise control"
        case .equalizer: return "Equalizer"
        case .speak: return "Speak-to-Chat"
        case .chatConfig: return "Speak-to-Chat options"
        case .powerOff: return "Automatic power-off"
        case .wearing: return "Wearing detection"
        case .listening: return "Listening mode"
        case .room: return "Room size"
        case .dsee: return "DSEE Extreme"
        case .source: return "Playback source"
        }
    }

    public func matches(_ s: HeadphoneState) -> Bool {
        switch self {
        case .ambient(let v): return s.ambient == v
        case .equalizer(let v): return s.equalizer?.preset == v
        case .speak(let v): return s.speakToChat == v
        case .chatConfig(let v): return s.chatConfig == v
        case .powerOff(let v): return s.powerOff == v
        case .wearing(let v): return s.wearingPause == v
        case .listening(let v): return s.listeningMode == v
        case .room(let v): return s.bgmRoom == v
        case .dsee(let v): return s.dsee == v
        case .source(let v): return s.devices?.contains { normalizedAddress($0.id) == normalizedAddress(v) && $0.isConnected && $0.isPlayback } == true
        }
    }

    public func packets(state s: HeadphoneState) -> [ControlPacket]? {
        guard s.confirmedXM6, !s.stale else { return nil }
        switch self {
        case .ambient(let v):
            guard let old = s.ambient, old.subtype == v.subtype,
                  old.hasWindNoiseByte == v.hasWindNoiseByte,
                  old.adaptiveEnabled == v.adaptiveEnabled,
                  old.adaptiveSensitivity == v.adaptiveSensitivity,
                  (0...20).contains(v.level) else { return nil }
            if v.subtype == 0x19 {
                guard v.adaptiveEnabled != nil, let sensitivity = v.adaptiveSensitivity, sensitivity <= 2 else { return nil }
            }
            return [.init(SonyCommands.buildAmbientSoundSet(v)), .init(SonyCommands.buildAmbientSoundGet(subtype: v.subtype))]
        case .equalizer(let v):
            guard let eq = s.equalizer, eq.subtype == 0x04, v != .custom else { return nil }
            return [.init(SonyCommands.buildEqualizerPresetSet(code: v.rawValue, subtype: eq.subtype)), .init(SonyCommands.buildEqualizerGet(subtype: eq.subtype))]
        case .speak(let v):
            guard s.speakToChat != nil else { return nil }
            return [.init(SonyCommands.buildSpeakToChatEnabledSet(v)), .init(SonyCommands.buildSpeakToChatEnabledGet())]
        case .chatConfig(let v):
            guard s.chatConfig != nil else { return nil }
            return [.init(SonyCommands.buildSpeakToChatConfigSet(v)), .init(SonyCommands.buildSpeakToChatConfigGet())]
        case .powerOff(let v):
            guard s.powerOff != nil else { return nil }
            return [.init(SonyCommands.buildAutomaticPowerOffSet(v)), .init(SonyCommands.buildAutomaticPowerOffGet())]
        case .wearing(let v):
            guard s.wearingPause != nil else { return nil }
            return [.init(SonyCommands.buildPauseWhenTakenOffSet(v)), .init(SonyCommands.buildPauseWhenTakenOffGet())]
        case .listening(let v):
            guard s.bgmEnabled != nil, s.cinema != nil, let room = s.bgmRoom, let subtype = s.bgmSubtype else { return nil }
            let bgm = ControlPacket(SonyCommands.buildBGMModeSet(enabled: v == .backgroundMusic, roomSize: room, subtype: subtype))
            let cinema = ControlPacket(SonyCommands.buildUpmixCinemaSet(enabled: v == .cinema))
            // Disable the conflicting effect first.
            let writes = v == .backgroundMusic ? [cinema, bgm] : [bgm, cinema]
            return writes + [.init(SonyCommands.buildBGMModeGet(subtype: subtype)), .init(SonyCommands.buildUpmixCinemaGet())]
        case .room(let v):
            guard let on = s.bgmEnabled, let subtype = s.bgmSubtype, s.bgmRoom != nil else { return nil }
            return [.init(SonyCommands.buildBGMModeSet(enabled: on, roomSize: v, subtype: subtype)), .init(SonyCommands.buildBGMModeGet(subtype: subtype))]
        case .dsee(let v):
            guard s.dsee != nil else { return nil }
            return [.init([0xe8, 0x01, v ? 0x01 : 0x00]), .init([0xe6, 0x01])]
        case .source(let address):
            guard s.devices?.contains(where: { normalizedAddress($0.id) == normalizedAddress(address) && $0.isConnected }) == true,
                  let payload = SonyCommands.buildSourceSwitchSet(macAddress: address) else { return nil }
            return [.init(payload, type: .command2), .init(SonyCommands.buildDeviceListGet(), type: .command2)]
        }
    }
}

public struct ControlPacket {
    public let payload: [UInt8]
    public let type: SonyMessageType
    public init(_ payload: [UInt8], type: SonyMessageType = .command1) { self.payload = payload; self.type = type }
}

public func normalizedAddress(_ s: String) -> String {
    s.uppercased().replacingOccurrences(of: "-", with: ":")
}

public func isBluetoothAddress(_ s: String) -> Bool {
    s.range(of: "^[0-9A-Fa-f]{2}([:-][0-9A-Fa-f]{2}){5}$", options: .regularExpression) != nil
}

public struct DiagnosticEntry: Identifiable {
    public let id = UUID()
    public let time: Date
    public let category: String
    public let message: String
}

public final class Diagnostics {
    public private(set) var entries: [DiagnosticEntry] = []
    public init() {}
    public func record(_ category: String, _ message: String, now: Date = Date()) {
        entries.append(.init(time: now, category: category, message: message))
        if entries.count > 300 { entries.removeFirst(entries.count - 300) }
    }
    public func report(redacting secrets: [String] = []) -> String {
        let formatter = ISO8601DateFormatter()
        let lines = entries.map { "\(formatter.string(from: $0.time)) [\($0.category)] \($0.message)" }
        var result = (["XM6 Studio diagnostics", "No audio recordings or raw Bluetooth packets are collected."] + lines).joined(separator: "\n")
        for secret in secrets.filter({ !$0.isEmpty }).sorted(by: { $0.count > $1.count }) { result = result.replacingOccurrences(of: secret, with: "[device]", options: .caseInsensitive) }
        result = result.replacingOccurrences(of: "(?i)[0-9a-f]{2}(?:[:-][0-9a-f]{2}){5}", with: "[address]", options: .regularExpression)
        return result
    }
}
