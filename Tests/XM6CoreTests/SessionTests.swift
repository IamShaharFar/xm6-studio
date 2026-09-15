import Testing
import Foundation
@testable import XM6Core

@MainActor final class MockTransport: HeadphoneTransport {
    var onEvent: ((UUID, TransportEvent) -> Void)?
    var id = UUID()
    var packets: [SonyMessage] = []
    var opens = 0
    var closes = 0
    var respond = true
    var honorWrites = true
    var model = "WH-1000XM6"
    var ambient: [UInt8] = [0x67,0x19,1,1,0,0,10,0,0]
    var active: UInt8 = 1
    let mac = "AA:BB:CC:DD:EE:01"
    let phone = "AA:BB:CC:DD:EE:02"
    func open(address: String, generation: UUID) { id = generation; opens += 1; if respond { onEvent?(id, .opened) } }
    func close(generation: UUID) { closes += 1 }
    func emit(_ payload: [UInt8], type: SonyMessageType = .command1) {
        onEvent?(id, .bytes(SonyMessage(type: type, sequenceNumber: 0, payload: payload).encode()))
    }
    func write(_ bytes: [UInt8], generation: UUID) {
        guard let msg = SonyMessage.decode(rawFrame: bytes) else { return }
        packets.append(msg)
        guard msg.type != .ack, respond else { return }
        let p = msg.payload
        if honorWrites && p.first == 0x68 { ambient = [0x67] + p.dropFirst() }
        if honorWrites && msg.type == .command2 && p.first == 0x3c {
            active = Array(p.dropFirst(2)) == Array(phone.utf8) ? 2 : 1
        }
        // Reply before ACK to exercise unsolicited notifications interleaved with the queue.
        switch p {
        case [0,0]: emit([1,0,0,0,2,0,1,1])
        case [4,1]: emit([5,1,UInt8(model.utf8.count)] + model.utf8)
        case [4,2]: emit([5,2,5] + Array("3.0.0".utf8))
        case [0x22,0]: emit([0x23,0,80,0])
        case [0x66,0x19]: emit(ambient)
        case [0x66,0x17]: emit([0x67,0x17,0,0,0,0,0])
        case [0x56,4]: emit([0x57,4,0,0])
        case [0xf6,0x0c]: emit([0xf7,0x0c,1,1])
        case [0xfa,0x0c]: emit([0xfb,0x0c,0,1])
        case [0x26,5]: emit([0x27,5,0x10,0])
        case [0xf6,1]: emit([0xf7,1,0])
        case [0xe6,9]: emit([0xe7,9,1,1])
        case [0xe6,4]: emit([0xe7,4,1])
        case [0xe6,1]: emit([0xe7,1,0])
        case [0x36,2] where msg.type == .command2:
            emit([0x37,2,2] + entry(mac, "Mac", 1) + entry(phone, "iPhone", 2) + [active], type: .command2)
        default: break
        }
        onEvent?(generation, .bytes(SonyMessage(type: .ack, sequenceNumber: msg.sequenceNumber ^ 1, payload: []).encode()))
    }
    func entry(_ address: String, _ name: String, _ status: UInt8) -> [UInt8] { Array(address.utf8) + [status,0,0,0,UInt8(name.utf8.count)] + Array(name.utf8) }
    var writes: [SonyMessage] { packets.filter { [UInt8(0x68),0x58,0xf8,0xfc,0x28,0xe8,0x3c].contains($0.payload.first ?? 0) && $0.type != .ack } }
}

@MainActor final class TestClock {
    var value = Date(timeIntervalSince1970: 1_000)
    func advance(_ seconds: Double) { value.addTimeInterval(seconds) }
}

@Test @MainActor func startupOnlyReadsSettings() {
    let transport = MockTransport(); let session = ControlSession(transport: transport, automaticTicks: false)
    transport.ambient = [0x67,0x19,1,0,0,0,0,0,0]
    session.resume(address: "headphones")
    #expect(session.status == .ready)
    #expect(session.state.model == "WH-1000XM6")
    #expect(session.state.firmware == "3.0.0")
    #expect(session.state.ambient?.mode == .off)
    #expect(session.state.ambient?.level == 0)
    #expect(transport.writes.isEmpty)
    #expect(session.writable)
}

@Test @MainActor func settingIsConfirmedByReportedState() {
    let t = MockTransport(); let s = ControlSession(transport: t, automaticTicks: false)
    s.resume(address: "headphones")
    var desired = s.state.ambient!; desired.mode = .ambientSound; desired.level = 17
    s.change(.ambient(desired))
    #expect(s.result?.succeeded == true)
    #expect(s.state.ambient?.level == 17)
    #expect(t.writes.count == 1)
}

@Test @MainActor func ackAloneDoesNotConfirmSettingOrReplayWrite() {
    let t = MockTransport(); t.honorWrites = false
    let clock = TestClock(); let s = ControlSession(transport: t, automaticTicks: false, now: { clock.value })
    s.resume(address: "headphones")
    var desired = s.state.ambient!; desired.mode = .ambientSound
    s.change(.ambient(desired))
    #expect(s.result == nil); #expect(s.busy)
    #expect(s.state.ambient?.mode == .noiseCancelling)
    clock.advance(13); s.tick(); clock.advance(2); s.tick()
    #expect(t.opens == 2)
    clock.advance(20); s.tick()
    #expect(s.result?.succeeded == false); #expect(!s.busy)
    #expect(t.writes.count == 1)
}

@Test @MainActor func idleReleasePreservesCachedStateAndBlocksWrites() {
    let t = MockTransport(); let clock = TestClock(); let s = ControlSession(transport: t, automaticTicks: false, now: { clock.value })
    s.resume(address: "headphones"); clock.advance(31); s.tick()
    #expect(s.status == .idle); #expect(s.state.stale); #expect(s.state.battery?.level == 80)
    s.change(.dsee(true)); #expect(t.writes.isEmpty)
    s.resume(address: "headphones"); #expect(s.status == .ready); #expect(!s.state.stale)
}

@Test @MainActor func explicitReleaseCancelsLateCallbacksAndRecovery() {
    let t = MockTransport(); let clock = TestClock(); let s = ControlSession(transport: t, automaticTicks: false, now: { clock.value })
    s.resume(address: "headphones"); let old = t.id
    s.release(forPhone: true)
    t.onEvent?(old, .closed); clock.advance(60); s.tick()
    #expect(s.status == .released); #expect(t.opens == 1)
    t.onEvent?(old, .bytes(SonyMessage(type: .command1, sequenceNumber: 0, payload: [0x23,0,2,0]).encode()))
    #expect(s.state.battery?.level == 80)
}

@Test @MainActor func onlyOneRecoveryAttempt() {
    let t = MockTransport(); t.respond = false
    let clock = TestClock(); let s = ControlSession(transport: t, automaticTicks: false, now: { clock.value })
    s.resume(address: "headphones")
    clock.advance(9); s.tick(); clock.advance(2); s.tick(); clock.advance(9); s.tick()
    #expect(t.opens == 2)
    if case .failed = s.status {} else { Issue.record("Expected failed status") }
    clock.advance(100); s.tick(); #expect(t.opens == 2)
}

@Test @MainActor func sourceSwitchPreservesBothDeviceConnections() {
    let t = MockTransport(); let s = ControlSession(transport: t, automaticTicks: false)
    s.resume(address: "headphones"); s.change(.source(t.phone))
    #expect(s.result?.succeeded == true)
    #expect(s.state.devices?.filter(\.isConnected).count == 2)
    #expect(s.state.devices?.first(where: \.isPlayback)?.id == t.phone)
    #expect(t.opens == 1)
    #expect(t.writes.allSatisfy { $0.type == .command2 && $0.payload.first == 0x3c })
}

@Test @MainActor func recoveryCanConfirmAppliedWriteWithoutReplayingIt() {
    let t = MockTransport(); t.honorWrites = false
    let clock = TestClock(); let s = ControlSession(transport: t, automaticTicks: false, now: { clock.value })
    s.resume(address: "headphones")
    var desired = s.state.ambient!; desired.mode = .ambientSound
    s.change(.ambient(desired))
    #expect(s.busy); #expect(s.result == nil)
    // Simulate a device applying the command but losing its report and control channel.
    t.ambient = [0x67] + SonyCommands.buildAmbientSoundSet(desired).dropFirst()
    t.onEvent?(t.id, .closed)
    clock.advance(2); s.tick()
    #expect(s.result?.succeeded == true); #expect(!s.busy)
    #expect(t.opens == 2); #expect(t.writes.count == 1)
}

@Test @MainActor func wrongModelAndUnreportedSettingsCannotBeWritten() {
    let t = MockTransport(); t.model = "WH-1000XM5"
    let s = ControlSession(transport: t, automaticTicks: false)
    s.resume(address: "headphones"); s.change(.dsee(true))
    #expect(!s.writable); #expect(t.writes.isEmpty)
    #expect(t.opens == 1)
    var state = HeadphoneState(); state.model = "WH-1000XM6"; state.stale = false
    #expect(HeadphoneChange.dsee(true).packets(state: state) == nil)
    #expect(HeadphoneChange.source("AA:BB:CC:DD:EE:FF").packets(state: state) == nil)
}
