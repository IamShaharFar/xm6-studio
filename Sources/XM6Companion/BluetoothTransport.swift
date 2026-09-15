import Foundation
import IOBluetooth
import XM6Core

private final class WorkItem: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}

/// IOBluetooth needs a running NSRunLoop. All native discovery, channel creation,
/// delegate callbacks and writes stay on this thread, never the SwiftUI thread.
final class BluetoothWorker: NSObject {
    private var thread: Thread!
    private var link: NativeLink?
    private var scanTimer: Timer?
    var onInventory: (([PairedHeadphone], String?) -> Void)?
    override init() {
        super.init()
        thread = Thread { [weak self] in
            let port = Port()
            RunLoop.current.add(port, forMode: .default)
            while !Thread.current.isCancelled { RunLoop.current.run(until: Date().addingTimeInterval(1)) }
            _ = self
        }
        thread.name = "XM6 Bluetooth"; thread.qualityOfService = .utility; thread.start()
    }
    func execute(_ body: @escaping () -> Void) {
        perform(#selector(run(_:)), on: thread, with: WorkItem(body), waitUntilDone: false)
    }
    @objc private func run(_ item: WorkItem) { item.action() }
    func startInventory() {
        execute { [self] in
            scan()
            scanTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.scan() }
        }
    }
    func scan() {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap { d -> PairedHeadphone? in
            guard let id = d.addressString else { return nil }
            return .init(id: id, name: d.name ?? "Paired Bluetooth device", connected: d.isConnected())
        }
        let address = IOBluetoothHostController.default()?.addressAsString()
        onInventory?(devices, address)
    }
    func open(address: String, id: UUID, event: @escaping (UUID, TransportEvent) -> Void) {
        execute { [self] in
            link?.invalidate()
            let next = NativeLink(id: id, event: event)
            link = next; next.open(address)
        }
    }
    func write(_ bytes: [UInt8], id: UUID) {
        execute { [weak self] in guard self?.link?.id == id else { return }; self?.link?.write(bytes) }
    }
    func close(_ id: UUID) {
        execute { [weak self] in
            guard self?.link?.id == id else { return }
            self?.link?.invalidate(); self?.link = nil
        }
    }
}

/// Discovery and framing transport adapted from xm6-control, revision in THIRD_PARTY.md.
private final class NativeLink: NSObject, IOBluetoothRFCOMMChannelDelegate {
    let id: UUID
    private var alive = true
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var disconnectNotification: IOBluetoothUserNotification?
    private let event: (UUID, TransportEvent) -> Void
    init(id: UUID, event: @escaping (UUID, TransportEvent) -> Void) { self.id = id; self.event = event }
    private func emit(_ e: TransportEvent) { if alive { event(id, e) } }
    func open(_ address: String) {
        guard let d = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?.first(where: { normalizedAddress($0.addressString ?? "") == normalizedAddress(address) }) else {
            emit(.failure("Pair your WH-1000XM6 in macOS Bluetooth settings first.")); return
        }
        guard d.isConnected() else {
            emit(.failure("Connect your headphones as a Mac audio device in Bluetooth settings first.")); return
        }
        device = d
        disconnectNotification = d.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        if let record = service(d) { openChannel(d, record); return }
        let status = d.performSDPQuery(self)
        if status != kIOReturnSuccess { emit(.failure("Bluetooth service discovery could not start (\(status)).")) }
    }
    func invalidate() {
        alive = false
        disconnectNotification?.unregister(); disconnectNotification = nil
        channel?.setDelegate(nil); _ = channel?.close(); channel = nil; device = nil
        // Do not call device.closeConnection(): it would also tear down audio/calls.
    }
    private func service(_ d: IOBluetoothDevice) -> IOBluetoothSDPServiceRecord? {
        for value in ["956C7B26-D49A-4BA8-B03F-B17D393CB6E2", "96CC203E-5068-46AD-B32D-E316F5E069BA"] {
            var uuid = UUID(uuidString: value)!.uuid
            let native = withUnsafeBytes(of: &uuid) { IOBluetoothSDPUUID(bytes: $0.baseAddress, length: $0.count) }
            if let record = d.getServiceRecord(for: native) { return record }
        }
        return nil
    }
    private func openChannel(_ d: IOBluetoothDevice, _ record: IOBluetoothSDPServiceRecord) {
        guard alive else { return }
        var number: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&number) == kIOReturnSuccess, number > 0 else { emit(.failure("No Sony control channel was advertised.")); return }
        var next: IOBluetoothRFCOMMChannel?
        let status = d.openRFCOMMChannelAsync(&next, withChannelID: number, delegate: self)
        channel = next
        if status != kIOReturnSuccess { emit(.failure("Sony control channel could not open (\(status)). Check Bluetooth permission or close Sony’s phone app.")) }
    }
    func write(_ bytes: [UInt8]) {
        guard alive, let channel, bytes.count <= Int(UInt16.max) else { return }
        var data = bytes
        let status = data.withUnsafeMutableBytes { channel.writeSync($0.baseAddress, length: UInt16($0.count)) }
        if status != kIOReturnSuccess { emit(.failure("Bluetooth write failed (\(status)).")) }
    }
    @objc func sdpQueryComplete(_ d: IOBluetoothDevice!, status: IOReturn) {
        guard alive, d === device else { return }
        guard status == kIOReturnSuccess, let record = service(d) else {
            emit(.failure("Sony control service was not available. Check Bluetooth permission and close Sony’s phone app.")); return
        }
        openChannel(d, record)
    }
    @objc func disconnected(_ notification: IOBluetoothUserNotification!, device: IOBluetoothDevice!) {
        emit(.failure("macOS reported a Bluetooth disconnect."))
    }
    func rfcommChannelOpenComplete(_ c: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        guard alive, c === channel else { return }
        guard status == kIOReturnSuccess else { emit(.failure("Control channel open failed (\(status)).")); return }
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in self?.emit(.opened) }
    }
    func rfcommChannelData(_ c: IOBluetoothRFCOMMChannel!, data pointer: UnsafeMutableRawPointer!, length count: Int) {
        guard alive, c === channel, let pointer, count > 0, count < 65_536 else { return }
        emit(.bytes(Array(UnsafeRawBufferPointer(start: pointer, count: count))))
    }
    func rfcommChannelClosed(_ c: IOBluetoothRFCOMMChannel!) {
        guard alive, c === channel else { return }; channel = nil; emit(.closed)
    }
}

@MainActor final class BluetoothTransport: HeadphoneTransport {
    var onEvent: ((UUID, TransportEvent) -> Void)?
    let worker = BluetoothWorker()
    func open(address: String, generation: UUID) {
        worker.open(address: address, id: generation) { [weak self] id, event in
            DispatchQueue.main.async { self?.onEvent?(id, event) }
        }
    }
    func write(_ bytes: [UInt8], generation: UUID) { worker.write(bytes, id: generation) }
    func close(generation: UUID) { worker.close(generation) }
}
