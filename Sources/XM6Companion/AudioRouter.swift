import Foundation
import Combine
import CoreAudio
import XM6Core

struct AudioOutput: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String
}

@MainActor final class AudioRouter: ObservableObject {
    @Published private(set) var outputs: [AudioOutput] = []
    @Published private(set) var selected: AudioDeviceID = 0
    var onChange: ((String) -> Void)?
    private var listener: AudioObjectPropertyListenerBlock?
    init() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        listener = block
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var p = Self.property(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &p, .main, block)
        }
        refresh()
    }
    static func property(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        .init(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    private func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
        var p = Self.property(selector); var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size); var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(id, &p, 0, nil, &size, &value) == noErr else { return "" }
        return value?.takeRetainedValue() as String? ?? ""
    }
    func refresh() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var p = Self.property(kAudioHardwarePropertyDevices); var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &p, 0, nil, &size) == noErr else { return }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &p, 0, nil, &size, &devices) == noErr else { return }
        outputs = devices.compactMap { id in
            var streams = Self.property(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput); var n: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &n) == noErr, n > 0 else { return nil }
            return AudioOutput(id: id, name: string(id, kAudioObjectPropertyName), uid: string(id, kAudioDevicePropertyDeviceUID))
        }
        var defaultProperty = Self.property(kAudioHardwarePropertyDefaultOutputDevice)
        var defaultID: AudioDeviceID = 0; var n = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(system, &defaultProperty, 0, nil, &n, &defaultID) == noErr {
            if selected != defaultID { onChange?("Mac audio output changed") }
            selected = defaultID
        }
    }
    func headphoneOutput(address: String, name: String) -> AudioOutput? {
        let normalized = normalizedAddress(address)
        if !normalized.isEmpty, let exact = outputs.first(where: { normalizedAddress($0.uid).contains(normalized) }) { return exact }
        let matches = outputs.filter { $0.name == name || $0.name.uppercased() == "WH-1000XM6" }
        return matches.count == 1 ? matches[0] : nil
    }
    func select(_ output: AudioOutput) -> Bool {
        var p = Self.property(kAudioHardwarePropertyDefaultOutputDevice); var id = output.id
        let result = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &p, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        refresh()
        return result == noErr && selected == output.id
    }
    var outputName: String { outputs.first(where: { $0.id == selected })?.name ?? "No audio output reported" }
}
