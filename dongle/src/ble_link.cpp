#include "ble_link.h"

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <Preferences.h>

#include <vector>

#include "hid_output.h"
#include "log.h"
#include "pc_channel.h"
#include "toca/advert.h"
#include "toca/packet.h"

namespace ble_link {

namespace {

// From ../protocol/PROTOCOL.md.
constexpr const char* kServiceUuid = "cc8e0001-115b-4a7a-8d7c-16299db8fcaf";
constexpr const char* kInputUuid = "cc8e0002-115b-4a7a-8d7c-16299db8fcaf";
constexpr const char* kInfoUuid = "cc8e0003-115b-4a7a-8d7c-16299db8fcaf";
constexpr const char* kNameUuid = "cc8e0004-115b-4a7a-8d7c-16299db8fcaf";
#if TOCA_PC_CHANNEL
constexpr const char* kControlUuid = "cc8e0005-115b-4a7a-8d7c-16299db8fcaf";
#endif

constexpr uint32_t kPairingWindowMs = 60000;
constexpr uint32_t kSecureWithinMs = 10000;
// 15 ms interval (12 x 1.25 ms), no peripheral latency, 2 s supervision timeout (200 x 10 ms).
constexpr uint16_t kConnInterval = 12;
constexpr uint16_t kSupervisionTimeout = 200;

constexpr uint16_t kNoConnection = 0xFFFF;
constexpr const char* kPrefsNamespace = "tocamatrol";
constexpr const char* kLegacyPrefsNamespace = "tiltpad";

// The name a phone gave the dongle, or "Tocamatrol XXXX". Changed only in the Arduino loop.
char deviceName[toca::kMaxNameLength + 1] = "Tocamatrol";
char defaultName[toca::kDongleNameSize] = "Tocamatrol";
// A name written by a phone (NimBLE host task), applied by tick() in the Arduino loop.
char pendingName[toca::kMaxNameLength + 1];
volatile bool namePending = false;
portMUX_TYPE nameLock = portMUX_INITIALIZER_UNLOCKED;
NimBLECharacteristic* nameChar = nullptr;
NimBLEServer* server = nullptr;
NimBLECharacteristic* info = nullptr;
#if TOCA_PC_CHANNEL
NimBLECharacteristic* control = nullptr;
bool lastScrollHold = false;
uint8_t lastControl[toca::kControlValueSize] = {};
#endif

// One slot per connected sender (e.g. an iPhone and an iPad); the slot index is the
// sender number hid_output merges by. Written from the NimBLE host task, read from the
// Arduino loop.
struct Link {
    volatile uint16_t handle = kNoConnection;
    volatile bool accepted = false;  // encrypted link with a sender allowed to send input
    volatile uint32_t connectedAt = 0;
};
constexpr size_t kMaxLinks = hid_output::kMaxSenders;
Link links[kMaxLinks];
portMUX_TYPE linkLock = portMUX_INITIALIZER_UNLOCKED;

// The slot holding `handle`, or kMaxLinks.
size_t slotOf(uint16_t handle) {
    for (size_t i = 0; i < kMaxLinks; ++i)
        if (links[i].handle == handle) return i;
    return kMaxLinks;
}

// The slot for `handle`, claiming a free one if it has none. Called from onConnect and from
// onAuthenticationComplete, because a sender with a stored bond can finish encrypting
// before NimBLE delivers onConnect.
size_t claimSlot(uint16_t handle) {
    portENTER_CRITICAL(&linkLock);
    size_t slot = slotOf(handle);
    if (slot < kMaxLinks) {
        portEXIT_CRITICAL(&linkLock);
        return slot;
    }
    slot = slotOf(kNoConnection);
    if (slot < kMaxLinks) {
        links[slot].handle = handle;
        links[slot].accepted = false;
        links[slot].connectedAt = millis();
    }
    portEXIT_CRITICAL(&linkLock);
    return slot;
}

size_t linksInUse() {
    size_t n = 0;
    for (const auto& l : links) n += l.handle != kNoConnection;
    return n;
}

bool linkAccepted(uint16_t handle) {
    const size_t slot = slotOf(handle);
    return slot < kMaxLinks && links[slot].accepted;
}

// Keep advertising while a slot is free, so another sender can connect.
void advertiseIfRoom() {
    if (linksInUse() < kMaxLinks && !NimBLEDevice::getAdvertising()->isAdvertising()) {
        NimBLEDevice::startAdvertising();
    }
}

volatile bool windowOpen = false;
volatile uint32_t windowClosesAt = 0;
volatile uint32_t packetCount = 0;

// Identity addresses of senders bonded inside a pairing window. Loaded from the bond store
// at boot; a bond that appears outside a window is not in here and gets deleted.
std::vector<NimBLEAddress> knownPhones;
portMUX_TYPE knownLock = portMUX_INITIALIZER_UNLOCKED;

bool isKnown(const NimBLEAddress& id) {
    portENTER_CRITICAL(&knownLock);
    bool found = false;
    for (const auto& a : knownPhones) found = found || a == id;
    portEXIT_CRITICAL(&knownLock);
    return found;
}

void remember(const NimBLEAddress& id) {
    portENTER_CRITICAL(&knownLock);
    knownPhones.push_back(id);
    portEXIT_CRITICAL(&knownLock);
}

void updateInfo() {
    const uint8_t value[4] = {toca::kProtocolVersion, FW_VERSION_MAJOR, FW_VERSION_MINOR,
                              static_cast<uint8_t>(windowOpen ? 0x01 : 0x00)};
    info->setValue(value, sizeof value);
}

// Rebuilds the advertisement and scan response (PROTOCOL.md "Advertising"): the service, the
// pairing-window flag and the name. Built from scratch each time, because NimBLE's setters
// append a field rather than replace it.
void updateAdvert() {
    NimBLEAdvertisementData data;
    data.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    data.addServiceUUID(kServiceUuid);
    uint8_t flags[toca::kAdvertDataSize];
    toca::advertData(windowOpen, flags);
    data.setManufacturerData(flags, sizeof flags);
    NimBLEAdvertisementData scanResponse;
    scanResponse.setName(deviceName);
    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setAdvertisementData(data);
    adv->setScanResponseData(scanResponse);
}

void setName(const char* name) {
    strncpy(deviceName, name, sizeof deviceName - 1);
    NimBLEDevice::setDeviceName(deviceName);
    nameChar->setValue(reinterpret_cast<const uint8_t*>(deviceName), strlen(deviceName));
    updateAdvert();
    LOG("ble: name %s\n", deviceName);
}

void setWindow(bool open, uint32_t nowMs) {
    windowOpen = open;
    windowClosesAt = nowMs + kPairingWindowMs;
    updateInfo();
    updateAdvert();
    LOG("ble: pairing window %s\n", open ? "open" : "closed");
}

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* s, NimBLEConnInfo& conn) override {
        const size_t slot = claimSlot(conn.getConnHandle());
        if (slot >= kMaxLinks) {
            LOG("ble: no free slot for %s\n", conn.getAddress().toString().c_str());
            s->disconnect(conn);
            return;
        }
        LOG("ble: connect %s (slot %u)\n", conn.getAddress().toString().c_str(), slot);
        if (conn.getConnInterval() > kConnInterval)
            s->updateConnParams(conn.getConnHandle(), kConnInterval, kConnInterval, 0, kSupervisionTimeout);
        LOG("ble: interval %.2f ms at connect\n", conn.getConnInterval() * 1.25);
        s->updatePhy(conn.getConnHandle(), BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK, 0);
        // Writes without response get no error back, so ask the phone to encrypt now.
        NimBLEDevice::startSecurity(conn.getConnHandle());
        advertiseIfRoom();
    }

    void onDisconnect(NimBLEServer*, NimBLEConnInfo& conn, int reason) override {
        portENTER_CRITICAL(&linkLock);
        const size_t slot = slotOf(conn.getConnHandle());
        if (slot < kMaxLinks) {
            links[slot].handle = kNoConnection;
            links[slot].accepted = false;
        }
        portEXIT_CRITICAL(&linkLock);
        // Release only what this sender held; the others keep theirs.
        if (slot < kMaxLinks) {
            hid_output::release(slot);
            pc_channel::senderLeft(slot);
        }
        LOG("ble: disconnect %s (slot %u) reason 0x%x\n", conn.getAddress().toString().c_str(), slot, reason);
        advertiseIfRoom();
    }

    void onAuthenticationComplete(NimBLEConnInfo& conn) override {
        if (!conn.isEncrypted()) {
            LOG("ble: pairing failed, disconnecting\n");
            server->disconnect(conn);
            return;
        }
        const size_t slot = claimSlot(conn.getConnHandle());
        const NimBLEAddress id = conn.getIdAddress();
        LOG("ble: encrypted %s (slot %u)\n", id.toString().c_str(), slot);
        if (slot >= kMaxLinks) {
            server->disconnect(conn);
            return;
        }
        if (isKnown(id)) {
            links[slot].accepted = true;
            pc_channel::senderConnected(slot);
            LOG("ble: known sender accepted\n");
        } else if (windowOpen) {
            remember(id);
            links[slot].accepted = true;
            pc_channel::senderConnected(slot);
            setWindow(false, millis());  // one new phone per window
            LOG("ble: bonded new phone %s\n", id.toString().c_str());
        } else {
            LOG("ble: refused new phone %s outside the pairing window\n", id.toString().c_str());
            NimBLEDevice::deleteBond(id);
            server->disconnect(conn);
        }
    }

    void onConnParamsUpdate(NimBLEConnInfo& conn) override {
        LOG("ble: interval %.2f ms, latency %u, timeout %u ms\n", conn.getConnInterval() * 1.25,
            conn.getConnLatency(), conn.getConnTimeout() * 10);
    }

    void onPhyUpdate(NimBLEConnInfo&, uint8_t txPhy, uint8_t rxPhy) override {
        LOG("ble: phy tx %u rx %u\n", txPhy, rxPhy);
    }
};

class InputCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& conn) override {
        const size_t slot = slotOf(conn.getConnHandle());
        if (slot >= kMaxLinks || !links[slot].accepted || !conn.isEncrypted()) return;
        const NimBLEAttValue& v = c->getValue();
        const toca::Decoded d = toca::decode(v.data(), v.size());
        if (d.status == toca::DecodeStatus::Pointer) {
            packetCount = packetCount + 1;
            if (!hid_output::submit(slot, d.pointer)) LOG("ble: hid queue full, pointer packet %u lost\n", d.pointer.seq);
        } else if (d.status == toca::DecodeStatus::Keyboard) {
            packetCount = packetCount + 1;
            if (!hid_output::submit(slot, d.keyboard)) LOG("ble: hid queue full, keyboard packet %u lost\n", d.keyboard.seq);
#if TOCA_PC_CHANNEL
        } else if (d.status == toca::DecodeStatus::ScrollRate) {
            packetCount = packetCount + 1;
            if (!hid_output::submitRate(slot, d.scrollRate.rateX16)) LOG("ble: hid queue full, rate lost\n");
        } else if (d.status == toca::DecodeStatus::Status) {
            pc_channel::senderStatus(slot, d.senderStatus);
            LOG("ble: sender %u battery %u%% %u mV\n", slot, d.senderStatus.batteryPercent, d.senderStatus.millivolts);
#endif
        } else {
            LOG("ble: dropped packet (status %d, %u bytes)\n", static_cast<int>(d.status), v.size());
        }
    }
};

class NameCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& conn) override {
        if (!linkAccepted(conn.getConnHandle()) || !conn.isEncrypted()) return;
        const NimBLEAttValue& v = c->getValue();
        portENTER_CRITICAL(&nameLock);
        toca::cleanName(v.data(), v.size(), pendingName);
        namePending = true;
        portEXIT_CRITICAL(&nameLock);
    }
};

ServerCallbacks serverCallbacks;
InputCallbacks inputCallbacks;
NameCallbacks nameCallbacks;

}  // namespace

void begin(uint32_t nowMs) {
    NimBLEDevice::init("Tocamatrol");
    const uint8_t* lsbFirst = NimBLEDevice::getAddress().getVal();
    const uint8_t address[6] = {lsbFirst[5], lsbFirst[4], lsbFirst[3], lsbFirst[2], lsbFirst[1], lsbFirst[0]};
    toca::dongleName(address, defaultName);
    NimBLEDevice::setSecurityAuth(/*bonding=*/true, /*mitm=*/false, /*sc=*/true);
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);
    NimBLEDevice::setDefaultPhy(BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK);

    for (int i = 0; i < NimBLEDevice::getNumBonds(); ++i) remember(NimBLEDevice::getBondedAddress(i));
    LOG("ble: %u bonded phone(s)\n", knownPhones.size());

    server = NimBLEDevice::createServer();
    server->setCallbacks(&serverCallbacks);
    // advertiseIfRoom() restarts advertising after a connect or disconnect, while a slot is free.
    server->advertiseOnDisconnect(false);

    NimBLEService* service = server->createService(kServiceUuid);
    NimBLECharacteristic* input =
        service->createCharacteristic(kInputUuid, NIMBLE_PROPERTY::WRITE_NR | NIMBLE_PROPERTY::WRITE_ENC);
    input->setCallbacks(&inputCallbacks);
    // Encrypted read: the phone's first read waits for pairing and doubles as its "ready" signal.
    info = service->createCharacteristic(kInfoUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC);
    nameChar = service->createCharacteristic(
        kNameUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC | NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC);
    nameChar->setCallbacks(&nameCallbacks);
#if TOCA_PC_CHANNEL
    control = service->createCharacteristic(kControlUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC |
                                                              NIMBLE_PROPERTY::NOTIFY);
    control->setValue(lastControl, sizeof lastControl);
#endif

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    // The name goes in the scan response: the advertisement is full with the 128-bit service
    // UUID and the manufacturer data.
    adv->enableScanResponse(true);
    Preferences prefs;
    prefs.begin(kPrefsNamespace, /*readOnly=*/true);
    String saved = prefs.getString("name", "");
    prefs.end();
    if (saved.length() == 0) {
        prefs.begin(kLegacyPrefsNamespace, /*readOnly=*/true);
        saved = prefs.getString("name", "");
        prefs.end();
    }
    setName(saved.length() > 0 ? saved.c_str() : defaultName);
    setWindow(true, nowMs);
    adv->start();
    LOG("ble: advertising\n");
}

void tick(uint32_t nowMs) {
    if (namePending) {
        char name[toca::kMaxNameLength + 1];
        portENTER_CRITICAL(&nameLock);
        memcpy(name, pendingName, sizeof name);
        namePending = false;
        portEXIT_CRITICAL(&nameLock);
        // An empty name restores the default, which is not stored.
        Preferences prefs;
        prefs.begin(kPrefsNamespace);
        if (name[0] != '\0') {
            prefs.putString("name", name);
        } else {
            prefs.remove("name");
        }
        prefs.end();
        if (name[0] == '\0') {
            prefs.begin(kLegacyPrefsNamespace);
            prefs.remove("name");
            prefs.end();
        }
        setName(name[0] != '\0' ? name : defaultName);
    }
    if (windowOpen && static_cast<int32_t>(nowMs - windowClosesAt) >= 0) setWindow(false, nowMs);
#if TOCA_PC_CHANNEL
    uint8_t value[toca::kControlValueSize];
    pc_channel::controlValue(nowMs, value);
    if (memcmp(value, lastControl, sizeof value) != 0) {
        memcpy(lastControl, value, sizeof value);
        control->setValue(value, sizeof value);
        control->notify();
        const bool scrollHold = value[0] & 0x01;
        if (!scrollHold && lastScrollHold) hid_output::stopRates();
        if (scrollHold != lastScrollHold) LOG("ble: scroll hold %s\n", scrollHold ? "on" : "off");
        lastScrollHold = scrollHold;
        LOG("ble: control 0x%02x mode %u\n", value[0], value[1]);
    }
#endif
    for (auto& link : links) {
        const uint16_t handle = link.handle;
        if (handle != kNoConnection && !link.accepted && nowMs - link.connectedAt > kSecureWithinMs) {
            LOG("ble: link not secured in time, disconnecting\n");
            server->disconnect(handle);
            link.connectedAt = nowMs;  // don't repeat while the disconnect completes
        }
    }
}

void openPairingWindow(uint32_t nowMs) { setWindow(true, nowMs); }

void forgetAllPhones(uint32_t nowMs) {
    for (const auto& link : links) {
        const uint16_t handle = link.handle;
        if (handle != kNoConnection) server->disconnect(handle);
    }
    NimBLEDevice::deleteAllBonds();
    portENTER_CRITICAL(&knownLock);
    knownPhones.clear();
    portEXIT_CRITICAL(&knownLock);
    LOG("ble: forgot all phones\n");
    setWindow(true, nowMs);
}

uint32_t packetsReceived() { return packetCount; }

const char* name() { return deviceName; }

uint32_t pairingWindowLeftMs(uint32_t nowMs) {
    const int32_t left = static_cast<int32_t>(windowClosesAt - nowMs);
    return windowOpen && left > 0 ? static_cast<uint32_t>(left) : 0;
}

uint8_t bondedPhones() {
    portENTER_CRITICAL(&knownLock);
    const size_t n = knownPhones.size();
    portEXIT_CRITICAL(&knownLock);
    return static_cast<uint8_t>(n);
}

uint8_t connectedSenders() {
    uint8_t n = 0;
    for (const auto& l : links) n += l.handle != kNoConnection && l.accepted;
    return n;
}

LinkState state() {
    if (connectedSenders() > 0) return LinkState::Connected;
    if (linksInUse() > 0) return LinkState::Securing;
    return windowOpen ? LinkState::PairingWindow : LinkState::Advertising;
}

}  // namespace ble_link
