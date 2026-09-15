import Testing
import Foundation
@testable import XM6Core

@Test func knownHandshakeFrame() {
    let expected: [UInt8] = [0x3e,0x0c,0,0,0,0,2,0,0,0x0e,0x3c]
    #expect(SonyMessage(type: .command1, sequenceNumber: 0, payload: [0,0]).encode() == expected)
    #expect(SonyMessage.decode(rawFrame: expected)?.payload == [0,0])
}

@Test func frameEscapingAndFragmentation() {
    let original = SonyMessage(type: .command2, sequenceNumber: 1, payload: [0x3c,0x3d,0x3e,0x00,0xff])
    let parser = FrameParser(); var results: [SonyMessage] = []
    for byte in original.encode() { results += parser.feed([byte]) }
    #expect(results == [original])
}

@Test func malformedFramesAndResynchronization() {
    let valid = SonyMessage(type: .command1, sequenceNumber: 0, payload: [0x22,0]).encode()
    var corrupt = valid; corrupt[7] ^= 0xff
    #expect(SonyMessage.decode(rawFrame: corrupt) == nil)
    let parser = FrameParser()
    #expect(parser.feed([0,0xff,0x3e,0x0c,0] + valid).count == 1)
    #expect(parser.feed([0x3e] + Array(repeating: 0, count: 9000)).isEmpty)
    #expect(parser.feed(valid + valid).count == 2)
    #expect(SonyMessage.decode(rawFrame: SonyMessage(type: .command1, sequenceNumber: 2, payload: []).encode()) == nil)
    #expect(SonyMessage.decode(rawFrame: SonyMessage(type: .ack, sequenceNumber: 0, payload: [1]).encode()) == nil)
}

@Test func malformedPayloadsRemainUnknown() {
    #expect(SonyCommands.decodeBattery([0x23,0,255,0]) == nil)
    #expect(SonyCommands.decodeBattery([0x23,0,80,3]) == nil)
    #expect(SonyCommands.decodeEqualizer([0x57,4,0,10,6]) == nil)
    #expect(SonyCommands.decodeAmbientSound([0x67,0x15,1,1,1,0]) == nil)
    #expect(SonyCommands.decodeBGMMode([0xe7,9,4,0]) == nil)
    #expect(SonyCommands.decodeDeviceList([0x37,2,20,0]) == nil)
    #expect(SonyCommands.decodeDeviceList([0x37,2,0,0]) == [])
    #expect(SonyCommands.buildSourceSwitchSet(macAddress: "not an address!!!") == nil)
    #expect(SonyCommands.buildSourceSwitchSet(macAddress: "AA:BB:CC:DD:EE:FF") == [0x3c,1] + Array("AA:BB:CC:DD:EE:FF".utf8))
}

@Test func truncatedMultipointNameCannotConsumePlaybackStatus() {
    let bytes: [UInt8] = [0x37,2,1] + Array("AA:BB:CC:DD:EE:FF".utf8) + [1,0,0,0,2,65,1]
    #expect(SonyCommands.decodeDeviceList(bytes) == nil)
}

@Test func opcodeTablesStaySeparate() {
    #expect(SonyEventDecoder.decode(payload: [0x23,0,80,0], messageType: .command2) == nil)
    #expect(SonyEventDecoder.decode(payload: [0x37,2,0,0], messageType: .command1) == nil)
}

@Test func diagnosticsRedactAndBoundData() {
    let log = Diagnostics()
    log.record("source", "Alice’s iPhone AA:BB:CC:DD:EE:FF and 11-22-33-44-55-66")
    let report = log.report(redacting: ["Alice’s iPhone"])
    #expect(!report.contains("Alice")); #expect(!report.contains("AA:BB")); #expect(!report.contains("11-22"))
    for _ in 0..<400 { log.record("test", "event") }
    #expect(log.entries.count == 300)
}

@Test func featureInventoryCoversSonyList() {
    #expect(FeatureCatalog.items.count == 43)
    #expect(Set(FeatureCatalog.items.map(\.name)).count == 43)
    #expect(FeatureCatalog.items.first(where: { $0.name == "Headset software updates" })?.mac == false)
    #expect(FeatureCatalog.items.first(where: { $0.name == "Custom equalizer editing" })?.mac == false)
}

@Test func modernNoiseVariantPreservesAdaptiveSettings() {
    let reply: [UInt8] = [0x67,0x19,1,1,0,1,17,1,2]
    let state = SonyCommands.decodeAmbientSound(reply)
    #expect(state?.mode == .noiseCancelling)
    #expect(state?.level == 17)
    #expect(state?.adaptiveEnabled == true)
    #expect(state?.adaptiveSensitivity == 2)
    #expect(SonyCommands.buildAmbientSoundSet(state!) == [0x68,0x19,1,1,0,1,17,1,2])
    #expect(SonyCommands.decodeAmbientSound(Array(reply.dropLast())) == nil)
}

@Test @MainActor func legacyNoiseReplyDoesNotOverrideModernState() {
    let t = MockTransport(); let s = ControlSession(transport: t, automaticTicks: false)
    s.resume(address: "headphones")
    #expect(s.state.ambient?.subtype == 0x19)
    #expect(s.state.ambient?.mode == .noiseCancelling)
    t.emit([0x69,0x17,0,0,0,0,0])
    #expect(s.state.ambient?.mode == .noiseCancelling)
}

@Test func noiseChangesCannotOverwriteUnexposedAdaptiveSettings() {
    var state = HeadphoneState(); state.model = "WH-1000XM6"; state.stale = false
    let original = SonyCommands.decodeAmbientSound([0x67,0x19,1,1,0,0,20,1,2])!
    state.ambient = original
    var edit = original; edit.mode = .ambientSound
    #expect(HeadphoneChange.ambient(edit).packets(state: state)?.count == 2)
    edit.adaptiveEnabled = false
    #expect(HeadphoneChange.ambient(edit).packets(state: state) == nil)
    edit = original; edit.adaptiveSensitivity = nil
    #expect(HeadphoneChange.ambient(edit).packets(state: state) == nil)
}

@Test func untrustedPacketFuzzDoesNotCrash() {
    // Deterministic malformed payload corpus, with valid subtype bytes mixed in.
    var seed: UInt64 = 71
    for count in 0..<128 {
        for _ in 0..<20 {
            let bytes: [UInt8] = (0..<count).map { _ in seed = seed &* 6364136223846793005 &+ 1; return UInt8(truncatingIfNeeded: seed >> 24) }
            _ = SonyEventDecoder.decode(payload: bytes, messageType: .command1)
            _ = SonyCommands.decodeDeviceList(bytes)
            _ = SonyMessage.decode(rawFrame: [0x3e] + bytes + [0x3c])
        }
    }
}
