import CoreBluetooth
import Foundation
import TocaCore

/// The phone's side of the BLE link: the dongles it knows, the ones nearby, and the link to the
/// one in use. It connects only to a dongle the person chose, waits for the encrypted Info read
/// (PROTOCOL.md "Info characteristic"), and reconnects on its own.
///
/// All Core Bluetooth callbacks arrive on the main queue.
final class DongleLink: NSObject, ObservableObject {
    enum State: Equatable {
        case bluetoothOff
        case unauthorized
        case unsupported
        /// No dongle chosen yet.
        case noDongle
        /// Waiting for the chosen dongle to be in range and powered.
        case connecting
        /// Connected; waiting for pairing or bond restore before input is accepted.
        case securing
        case ready
        /// The dongle dropped us during pairing: its pairing window is probably closed.
        case refused
        /// The dongle no longer has this phone's bond (it forgot every phone), but iOS still
        /// has the dongle's. iOS will not pair again until the dongle is forgotten in Settings.
        case bondLost
    }

    /// A dongle this phone has paired with.
    struct KnownDongle: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var lastConnected: Date
    }

    /// A dongle advertising nearby, seen while browsing.
    struct NearbyDongle: Identifiable, Equatable {
        let id: UUID
        var name: String
        var rssi: Int
        /// nil when the dongle does not say (firmware before the flag).
        var pairingWindowOpen: Bool?
        var lastSeen: Date
    }

    @Published private(set) var state: State = .bluetoothOff
    /// The dongle in use, if one has been chosen.
    @Published private(set) var currentID: UUID?
    @Published private(set) var known: [KnownDongle] = []
    @Published private(set) var nearby: [NearbyDongle] = []
    /// Signal strength of the connected dongle in dBm, refreshed while browsing.
    @Published private(set) var rssi: Int?
    /// "firmware 0.1" once the Info read succeeds.
    @Published private(set) var dongleInfo: String?

    /// Called when the link drops, so input state can be reset.
    var onDisconnect: (() -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var input: CBCharacteristic?
    private var nameCharacteristic: CBCharacteristic?
    private var browsers = 0
    private var browseTimer: Timer?

    private static let serviceUUID = CBUUID(string: TocaProtocol.serviceUUID)
    private static let inputUUID = CBUUID(string: TocaProtocol.inputUUID)
    private static let infoUUID = CBUUID(string: TocaProtocol.infoUUID)
    private static let nameUUID = CBUUID(string: TocaProtocol.nameUUID)
    private static let currentKey = "lastDongleIdentifier"
    private static let knownKey = "knownDongles"
    /// A nearby dongle not heard from for this long has gone.
    private static let nearbyTimeout: TimeInterval = 5

    override init() {
        super.init()
        loadKnown()
        central = CBCentralManager(delegate: self, queue: .main)
        #if DEBUG
        if UITestSupport.isActive { showUITestDongles() }
        #endif
    }

    #if DEBUG
    /// The screenshot catalog's pretend dongles: one in use, one paired, one new nearby.
    private func showUITestDongles() {
        let now = Date()
        known = [KnownDongle(id: UITestSupport.currentDongle, name: "Tocamatrol 566D", lastConnected: now),
                 KnownDongle(id: UITestSupport.otherDongle, name: "Studio Mac", lastConnected: now)]
        nearby = [NearbyDongle(id: UITestSupport.otherDongle, name: "Studio Mac", rssi: -58,
                               pairingWindowOpen: false, lastSeen: .distantFuture),
                  NearbyDongle(id: UITestSupport.newDongle, name: "Tocamatrol A93C", rssi: -71,
                               pairingWindowOpen: true, lastSeen: .distantFuture)]
        currentID = UITestSupport.currentDongle
        rssi = -52
        dongleInfo = "firmware 0.2"
        state = .ready
    }
    #endif

    /// True when a packet written now will go out.
    var canSend: Bool {
        guard state == .ready, let peripheral, input != nil else { return false }
        return peripheral.canSendWriteWithoutResponse
    }

    func send(_ bytes: [UInt8]) {
        guard state == .ready, let peripheral, let input else { return }
        peripheral.writeValue(Data(bytes), for: input, type: .withoutResponse)
    }

    /// The name to show for a dongle: the advertised "Tocamatrol 566D" when known.
    func name(of id: UUID?) -> String {
        guard let id else { return "No dongle" }
        // The known name first: it is read from the dongle itself on connect.
        return known.first { $0.id == id }?.name ?? nearby.first { $0.id == id }?.name ?? "Tocamatrol"
    }

    func nearbyDongle(_ id: UUID?) -> NearbyDongle? {
        nearby.first { $0.id == id }
    }

    // MARK: - Choosing dongles

    /// Makes `id` the dongle in use and connects to it. A dongle not yet paired pairs now, if its
    /// pairing window is open.
    func use(_ id: UUID) {
        guard central.state == .poweredOn else { return }
        if id == currentID, state == .ready || state == .securing { return }
        if id != currentID { dropCurrent() }
        currentID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.currentKey)
        if let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(p)
        }
    }

    /// Removes a dongle from this phone's list. If it is the one in use, the link drops and no
    /// dongle is in use until another is chosen.
    func forget(_ id: UUID) {
        known.removeAll { $0.id == id }
        saveKnown()
        guard id == currentID else { return }
        dropCurrent()
        currentID = nil
        UserDefaults.standard.removeObject(forKey: Self.currentKey)
        state = central.state == .poweredOn ? .noDongle : state
    }

    /// The dongle in use can be renamed: it is connected and its firmware has a name.
    var canRename: Bool { state == .ready && nameCharacteristic != nil }

    /// Renames the dongle in use (PROTOCOL.md "Name characteristic"). An empty name restores
    /// the dongle's default, "Tocamatrol 566D".
    func rename(to name: String) {
        guard canRename, let peripheral, let nameCharacteristic else { return }
        peripheral.writeValue(Data(DongleName.bytes(for: name)), for: nameCharacteristic, type: .withResponse)
    }

    /// Tries the dongle in use again, after a refused pairing.
    func retry() {
        if let currentID { use(currentID) }
    }

    /// Scans for nearby dongles until `stopBrowsing`. Calls nest.
    func startBrowsing() {
        browsers += 1
        guard browsers == 1 else { return }
        scan()
        browseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.browseTick() }
    }

    func stopBrowsing() {
        browsers = max(0, browsers - 1)
        guard browsers == 0 else { return }
        browseTimer?.invalidate()
        browseTimer = nil
        if !needsScan { central.stopScan() }
        nearby = []
        rssi = nil
    }

    // MARK: - Connecting

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        state = .connecting
        // A pending connect never times out, so this also waits for the dongle to come back.
        central.connect(p)
    }

    /// Disconnects from the dongle in use without reconnecting.
    private func dropCurrent() {
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        let wasReady = state == .ready
        peripheral = nil
        forgetLink()
        if wasReady { onDisconnect?() }
    }

    private func forgetLink() {
        input = nil
        nameCharacteristic = nil
        dongleInfo = nil
        rssi = nil
    }

    /// Scanning goes on while browsing, and after a refused pairing, to see the dongle's pairing
    /// window open.
    private var needsScan: Bool { browsers > 0 || state == .refused }

    private func scan() {
        guard central.state == .poweredOn else { return }
        // Duplicates, so the signal strength and the pairing-window flag stay current.
        central.scanForPeripherals(withServices: [Self.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    private func browseTick() {
        let now = Date()
        nearby.removeAll { now.timeIntervalSince($0.lastSeen) > Self.nearbyTimeout }
        if state == .ready { peripheral?.readRSSI() }
    }

    private func markReady(_ p: CBPeripheral) {
        let name = nearbyDongle(p.identifier)?.name ?? p.name.flatMap { $0.hasPrefix("Tocamatrol ") ? $0 : nil }
        if let i = known.firstIndex(where: { $0.id == p.identifier }) {
            known[i].lastConnected = Date()
            if let name { known[i].name = name }
        } else {
            known.append(KnownDongle(id: p.identifier, name: name ?? "Tocamatrol", lastConnected: Date()))
        }
        saveKnown()
        state = .ready
        if !needsScan && browsers == 0 { central.stopScan() }
    }

    private func setKnownName(_ name: String, for id: UUID) {
        if let i = known.firstIndex(where: { $0.id == id }), known[i].name != name {
            known[i].name = name
            saveKnown()
        }
        if let i = nearby.firstIndex(where: { $0.id == id }) { nearby[i].name = name }
    }

    private func loadKnown() {
        if let data = UserDefaults.standard.data(forKey: Self.knownKey),
           let list = try? JSONDecoder().decode([KnownDongle].self, from: data) {
            known = list
        }
        if let idString = UserDefaults.standard.string(forKey: Self.currentKey), let id = UUID(uuidString: idString) {
            currentID = id
            // Paired before the app kept a list: it is known.
            if !known.contains(where: { $0.id == id }) {
                known.append(KnownDongle(id: id, name: "Tocamatrol", lastConnected: Date()))
                saveKnown()
            }
        }
    }

    private func saveKnown() {
        if let data = try? JSONEncoder().encode(known) {
            UserDefaults.standard.set(data, forKey: Self.knownKey)
        }
    }
}

extension DongleLink: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if DEBUG
        // The simulator has no Bluetooth: keep the pretend dongles.
        if UITestSupport.isActive { return }
        #endif
        switch central.state {
        case .poweredOn:
            if let currentID {
                use(currentID)
            } else {
                state = .noDongle
            }
            if needsScan { scan() }
        case .unauthorized:
            state = .unauthorized
        case .unsupported:
            state = .unsupported
        default:
            forgetLink()
            state = .bluetoothOff
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let flags = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
            .flatMap { DongleAdvert(manufacturerData: [UInt8]($0)) }
        let rssi = RSSI.intValue
        // 127 means "not available".
        guard rssi != 127 else { return }
        if let i = nearby.firstIndex(where: { $0.id == peripheral.identifier }) {
            if let advertised { nearby[i].name = advertised }
            if let flags { nearby[i].pairingWindowOpen = flags.pairingWindowOpen }
            nearby[i].rssi = rssi
            nearby[i].lastSeen = Date()
        } else {
            nearby.append(NearbyDongle(id: peripheral.identifier, name: advertised ?? name(of: peripheral.identifier),
                                       rssi: rssi, pairingWindowOpen: flags?.pairingWindowOpen, lastSeen: Date()))
            nearby.sort { $0.rssi > $1.rssi }
        }
        if let advertised, let i = known.firstIndex(where: { $0.id == peripheral.identifier }), known[i].name != advertised {
            known[i].name = advertised
            saveKnown()
        }
        // Refused, and now the window is open: pair again without being asked.
        if state == .refused, peripheral.identifier == currentID, flags?.pairingWindowOpen == true {
            use(peripheral.identifier)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == currentID else { return }
        state = .securing
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == currentID else { return }
        forgetLink()
        if (error as? CBError)?.code == .peerRemovedPairingInformation {
            state = .bondLost
            return
        }
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        // Only the dongle in use matters; one just switched away from is done with.
        guard peripheral.identifier == currentID, self.peripheral != nil else { return }
        let wasSecuring = state == .securing
        let wasReady = state == .ready
        forgetLink()
        if wasReady { onDisconnect?() }
        guard central.state == .poweredOn else { return }
        if (error as? CBError)?.code == .peerRemovedPairingInformation {
            state = .bondLost
        } else if wasSecuring {
            // Wait for the pairing window (see didDiscover) or a retry; reconnecting now would
            // only be refused again.
            state = .refused
            scan()
        } else {
            // Reconnect to the same dongle whenever it is back in range.
            connect(peripheral)
        }
    }
}

extension DongleLink: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.inputUUID, Self.infoUUID, Self.nameUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        input = service.characteristics?.first { $0.uuid == Self.inputUUID }
        // Firmware before the name has none.
        nameCharacteristic = service.characteristics?.first { $0.uuid == Self.nameUUID }
        if let info = service.characteristics?.first(where: { $0.uuid == Self.infoUUID }) {
            // Encrypted read: completes after pairing (iOS shows the pairing sheet the first time).
            peripheral.readValue(for: info)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == Self.nameUUID {
            if error == nil, let value = characteristic.value, let name = String(data: value, encoding: .ascii),
               !name.isEmpty {
                setKnownName(name, for: peripheral.identifier)
            }
            return
        }
        guard characteristic.uuid == Self.infoUUID, peripheral.identifier == currentID else { return }
        guard error == nil, let value = characteristic.value, value.count >= 4 else {
            state = .refused
            scan()
            return
        }
        let bytes = [UInt8](value)
        dongleInfo = "firmware \(bytes[1]).\(bytes[2])"
        if input == nil {
            state = .refused
        } else {
            markReady(peripheral)
            // The name the dongle keeps, which iOS's cached Bluetooth name may lag.
            if let nameCharacteristic { peripheral.readValue(for: nameCharacteristic) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Read back what the dongle kept (it cleans names, and empty means its default).
        if characteristic.uuid == Self.nameUUID, error == nil { peripheral.readValue(for: characteristic) }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil, peripheral.identifier == currentID else { return }
        rssi = RSSI.intValue
    }
}
