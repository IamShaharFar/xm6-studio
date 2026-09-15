import Foundation
import Combine

public enum TransportEvent { case opened, bytes([UInt8]), closed, failure(String) }

@MainActor public protocol HeadphoneTransport: AnyObject {
    var onEvent: ((UUID, TransportEvent) -> Void)? { get set }
    func open(address: String, generation: UUID)
    func write(_ bytes: [UInt8], generation: UUID)
    func close(generation: UUID)
}

@MainActor public final class ControlSession: ObservableObject {
    @Published public private(set) var status: ControlStatus = .idle
    @Published public private(set) var state = HeadphoneState()
    @Published public private(set) var result: CommandResult?
    @Published public private(set) var busy = false
    @Published public private(set) var notice: String?
    public let diagnostics = Diagnostics()
    public var releasedForPhone: Bool { status == .released }
    public var writable: Bool { status == .ready && state.confirmedXM6 && !state.stale && !busy }

    private let transport: HeadphoneTransport
    private let now: () -> Date
    private var timer: Timer?
    private var parser = FrameParser()
    private var generation = UUID()
    private var target: String?
    private var queue: [ControlPacket] = []
    private var sequence: UInt8 = 0
    private var flight: ControlPacket?
    private var ackDeadline: Date?
    private var connectDeadline: Date?
    private var stateDeadline: Date?
    private var idleDeadline: Date?
    private var retryAt: Date?
    private var recoveryUsed = false
    private var pending: HeadphoneChange?
    private var commandDeadline: Date?
    private var modelRejected = false

    public init(transport: HeadphoneTransport, automaticTicks: Bool = true, now: @escaping () -> Date = Date.init) {
        self.transport = transport; self.now = now
        transport.onEvent = { [weak self] id, event in self?.receive(id, event) }
        if automaticTicks {
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    public func resume(address: String) {
        guard !busy else { return }
        if target == address, status == .ready {
            idleDeadline = now().addingTimeInterval(30)
            requestState()
            return
        }
        if target != address { state = HeadphoneState() }
        target = address; result = nil; notice = nil
        recoveryUsed = false; modelRejected = false
        beginAttempt()
    }

    public func clearSelection() {
        release()
        target = nil; state = HeadphoneState(); result = nil; notice = nil
    }

    public func release(forPhone: Bool = false) {
        if pending != nil { result = .unconfirmed("The controls were released before the change was confirmed. Refresh to check.") }
        closeAttempt()
        pending = nil; busy = false; retryAt = nil; commandDeadline = nil
        state.stale = true; status = forPhone ? .released : .idle
        diagnostics.record("control", forPhone ? "Released for Sony app" : "Control channel released; audio left connected")
    }

    public func audioDisconnected() {
        if status == .ready || status == .connecting {
            release()
            notice = "The headphones disconnected from macOS. Reconnect in Bluetooth settings, then refresh controls."
        }
        diagnostics.record("bluetooth", "macOS reports headphones disconnected")
    }

    public func reject(_ message: String) { result = .failed(message) }

    public func change(_ change: HeadphoneChange) {
        guard writable, let packets = change.packets(state: state) else {
            result = .failed("Refresh controls first. This setting must be reported by your WH-1000XM6 before it can be changed.")
            return
        }
        idleDeadline = now().addingTimeInterval(30)
        if change.matches(state) { result = .confirmed("\(change.label) is already selected."); return }
        recoveryUsed = false
        pending = change; busy = true; result = nil
        commandDeadline = now().addingTimeInterval(12)
        diagnostics.record("command", "Requested \(change.label)")
        if case .ambient(let v) = change {
            diagnostics.record("noise", "Requested mode=\(v.mode.rawValue), level=\(v.level), voice=\(v.focusOnVoice), variant=\(v.subtype)")
        }
        // Preserve an in-flight request, but drop optional queued refresh queries.
        queue = packets
        sendNext()
    }

    public func tick() {
        let t = now()
        if let deadline = retryAt, t >= deadline { retryAt = nil; beginAttempt(); return }
        if let deadline = connectDeadline, t >= deadline { recover("The headphones did not open their control service."); return }
        if let deadline = ackDeadline, t >= deadline { recover("The headphones stopped acknowledging control messages."); return }
        if let deadline = commandDeadline, t >= deadline {
            commandDeadline = nil
            if !recoveryUsed { recover("The setting was not confirmed."); return }
            finishUnconfirmed()
        }
        if let deadline = stateDeadline, t >= deadline {
            stateDeadline = nil
            if state.model == nil { notice = "Model identification was not reported. Editing is disabled; try closing Sony’s app and refreshing." }
            else if state.battery == nil || state.ambient == nil { notice = "Some settings were not reported. Unavailable controls stay disabled." }
        }
        if !busy, let deadline = idleDeadline, t >= deadline, status == .ready { release() }
    }

    private func beginAttempt() {
        guard let target else { return }
        closeAttempt()
        generation = UUID(); sequence = 0; parser.reset()
        // A new session must obtain fresh capabilities; never write using cached values.
        state = HeadphoneState()
        status = .connecting
        connectDeadline = now().addingTimeInterval(8)
        idleDeadline = now().addingTimeInterval(30)
        diagnostics.record("control", "Opening control channel")
        transport.open(address: target, generation: generation)
    }

    private func closeAttempt() {
        transport.close(generation: generation)
        generation = UUID() // invalidate late callbacks immediately
        queue.removeAll(); flight = nil; parser.reset()
        ackDeadline = nil; connectDeadline = nil; stateDeadline = nil; idleDeadline = nil
    }

    private func recover(_ reason: String) {
        diagnostics.record("control", reason)
        closeAttempt(); state.stale = true
        guard !recoveryUsed, !modelRejected else {
            status = .failed(reason)
            notice = "\(reason) Check Bluetooth permission, close Sony’s phone app, and refresh. Mac audio has not been disconnected."
            if pending != nil { finishUnconfirmed() }
            return
        }
        recoveryUsed = true
        status = .connecting
        notice = "Reopening controls once…"
        retryAt = now().addingTimeInterval(1)
        if pending != nil { commandDeadline = now().addingTimeInterval(18) }
        // Uncertain writes are never replayed. Recovery only reads their actual result.
    }

    private func finishUnconfirmed() {
        let name = pending?.label ?? "Change"
        result = .unconfirmed("\(name) was not confirmed. The headphones may have kept their previous setting. Refresh to check.")
        pending = nil; busy = false; commandDeadline = nil
        diagnostics.record("command", "\(name) unconfirmed")
    }

    private func sendNext() {
        guard flight == nil, !queue.isEmpty else { return }
        let packet = queue.removeFirst(); flight = packet
        ackDeadline = now().addingTimeInterval(2)
        transport.write(SonyMessage(type: packet.type, sequenceNumber: sequence, payload: packet.payload).encode(), generation: generation)
    }

    private func requestState() {
        state = HeadphoneState()
        state.stale = false
        let queries: [ControlPacket] = [
            .init([0x04, 0x01]), .init([0x04, 0x02]),
            .init(SonyCommands.buildBatteryGet()), .init(SonyCommands.buildAmbientSoundGet(subtype: 0x19)),
            .init(SonyCommands.buildAmbientSoundGet(subtype: 0x17)),
            .init(SonyCommands.buildDeviceListGet(), type: .command2),
            .init(SonyCommands.buildEqualizerGet()), .init(SonyCommands.buildSpeakToChatEnabledGet()),
            .init(SonyCommands.buildSpeakToChatConfigGet()), .init(SonyCommands.buildAutomaticPowerOffGet()),
            .init(SonyCommands.buildPauseWhenTakenOffGet()), .init(SonyCommands.buildBGMModeGet()),
            .init(SonyCommands.buildUpmixCinemaGet()), .init([0xe6, 0x01])
        ]
        queue = queries; stateDeadline = now().addingTimeInterval(6); sendNext()
    }

    private func receive(_ id: UUID, _ event: TransportEvent) {
        guard id == generation else { return }
        switch event {
        case .opened:
            queue = [.init(SonyCommands.buildInit())]; sendNext()
        case .closed: recover("The Sony control channel closed.")
        case .failure(let reason): recover(reason)
        case .bytes(let bytes):
            for message in parser.feed(bytes) {
                guard id == generation else { break }
                handle(message)
            }
        }
    }

    private func handle(_ message: SonyMessage) {
        if message.type == .ack {
            guard flight != nil, message.sequenceNumber == sequence ^ 1 else { return }
            sequence = message.sequenceNumber; flight = nil; ackDeadline = nil; sendNext()
            return
        }
        transport.write(SonyMessage(type: .ack, sequenceNumber: message.sequenceNumber ^ 1, payload: []).encode(), generation: generation)
        let p = message.payload
        if message.type == .command1, p.first == 0x01 {
            guard SonyCommands.protocolVersion(fromInitReplyPayload: p) == .v2 else {
                modelRejected = true; recover("This control protocol is not a supported XM6 protocol."); return
            }
            if status == .connecting {
                status = .ready; connectDeadline = nil; state.stale = false; notice = nil
                requestState()
                diagnostics.record("control", "Control session ready")
            }
            return
        }
        guard status == .ready else { return }
        var updated = false
        if message.type == .command1, p.count >= 4, p[0] == 0x05, (p[1] == 1 || p[1] == 2),
           Int(p[2]) == p.count - 3, let text = String(bytes: p.dropFirst(3), encoding: .utf8), !text.isEmpty {
            if p[1] == 1 {
                state.model = text
                if !state.confirmedXM6 { modelRejected = true; recover("The selected device did not identify as WH-1000XM6."); return }
            } else { state.firmware = text }
            updated = true
        } else if message.type == .command1, p.count == 3, (p[0] == 0xe7 || p[0] == 0xe9), p[1] == 1, p[2] <= 1 {
            state.dsee = p[2] == 1; updated = true
        } else if let e = SonyEventDecoder.decode(payload: p, messageType: message.type) {
            updated = true
            switch e {
            case .protocolInfo: updated = false
            case .ambientSound(let v):
                // Prefer the modern 0x19 variant. Some firmware answers legacy
                // queries with an unrelated Off value, which must not override it.
                if state.ambient?.subtype != 0x19 || v.subtype == 0x19 { state.ambient = v }
                diagnostics.record("noise", "Reported mode=\(v.mode.rawValue), level=\(v.level), voice=\(v.focusOnVoice), variant=\(v.subtype)")
            case .battery(let v): state.battery = v
            case .equalizer(let v): state.equalizer = v
            case .speakToChatEnabled(let v): state.speakToChat = v
            case .speakToChatConfig(let v): state.chatConfig = v
            case .automaticPowerOff(let v): state.powerOff = v
            case .pauseWhenTakenOff(let v): state.wearingPause = v
            case .bgmMode(let on, let room): state.bgmEnabled = on; state.bgmRoom = room; state.bgmSubtype = p[1]
            case .upmixCinema(let v): state.cinema = v
            case .deviceList(let v):
                let oldSource = state.devices?.first(where: \.isPlayback)?.id
                let newSource = v.first(where: \.isPlayback)?.id
                if oldSource != newSource { diagnostics.record("source", "Headphones reported a playback source change") }
                state.devices = v
            }
        }
        if updated {
            state.lastUpdated = now()
            if let change = pending, change.matches(state) {
                result = .confirmed("\(change.label) confirmed by headphones.")
                diagnostics.record("command", "\(change.label) confirmed")
                pending = nil; busy = false; commandDeadline = nil
                idleDeadline = now().addingTimeInterval(30)
            }
        }
    }
}
