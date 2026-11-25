#include "pc_channel.h"

#if TOCA_PC_CHANNEL

#include <Arduino.h>
#include <USBHID.h>

#include "log.h"
#include "toca/pc_status.h"

namespace pc_channel {

namespace {

// Usage page 0xFF00, usage 1: two 15-byte feature reports, status (0x10, read) and control
// (0x11, write). Same size, so Windows' HidD_GetFeature/HidD_SetFeature buffers match.
#define TOCA_FEATURE_REPORT(id, usage)                                                           \
    HID_REPORT_ID(id) HID_USAGE(usage), HID_LOGICAL_MIN(0x00), HID_LOGICAL_MAX_N(0xFF, 2),       \
        HID_REPORT_SIZE(8), HID_REPORT_COUNT(toca::kPcReportSize),                                \
        HID_FEATURE(HID_DATA | HID_VARIABLE | HID_ABSOLUTE)

const uint8_t kDescriptor[] = {
    HID_USAGE_PAGE_N(HID_USAGE_PAGE_VENDOR, 2),
    HID_USAGE(0x01),
    HID_COLLECTION(HID_COLLECTION_APPLICATION),
    TOCA_FEATURE_REPORT(toca::kStatusReportId, 0x02),
    TOCA_FEATURE_REPORT(toca::kControlReportId, 0x03),
    HID_COLLECTION_END,
};

portMUX_TYPE lock = portMUX_INITIALIZER_UNLOCKED;
toca::SenderSlot slots[toca::kStatusSlots];
toca::ScrollHold hold;
bool reverse = false;
uint8_t senderMode = 0;

// Registers itself when constructed, before setup(), as the mouse and keyboard do: a debug
// build starts USB (for its serial port) before setup(), and the HID descriptor is fixed then.
class StatusCollection : public USBHIDDevice {
   public:
    StatusCollection() { hid.addDevice(this, sizeof kDescriptor); }

    uint16_t _onGetDescriptor(uint8_t* dst) override {
        memcpy(dst, kDescriptor, sizeof kDescriptor);
        return sizeof kDescriptor;
    }

    // TinyUSB has already put the report ID in front of `buffer`.
    uint16_t _onGetFeature(uint8_t reportId, uint8_t* buffer, uint16_t len) override {
        if (reportId != toca::kStatusReportId || len < toca::kPcReportSize) return 0;
        uint8_t out[toca::kPcReportSize];
        const uint32_t now = millis();
        portENTER_CRITICAL(&lock);
        toca::encodeStatusReport(slots, hold.active(now), out);
        portEXIT_CRITICAL(&lock);
        memcpy(buffer, out, sizeof out);
        return sizeof out;
    }

    void _onSetFeature(uint8_t reportId, const uint8_t* buffer, uint16_t len) override {
        toca::Control c;
        if (reportId != toca::kControlReportId || !toca::decodeControlReport(buffer, len, c)) {
            LOG("pc: ignored feature report 0x%02x (%u bytes)\n", reportId, len);
            return;
        }
        const uint32_t now = millis();
        portENTER_CRITICAL(&lock);
        hold.set(c.scrollHold, now);
        reverse = c.reverse;
        senderMode = c.senderMode;
        portEXIT_CRITICAL(&lock);
    }

   private:
    USBHID hid;
};

StatusCollection collection;

}  // namespace

void begin() {}  // registered by the constructor; kept as the module's start point

void senderConnected(size_t slot) {
    if (slot >= toca::kStatusSlots) return;
    portENTER_CRITICAL(&lock);
    slots[slot] = toca::SenderSlot{toca::SlotState::Connected, toca::kBatteryUnknown, 0};
    portEXIT_CRITICAL(&lock);
}

void senderLeft(size_t slot) {
    if (slot >= toca::kStatusSlots) return;
    portENTER_CRITICAL(&lock);
    slots[slot] = toca::SenderSlot{};
    portEXIT_CRITICAL(&lock);
}

void senderStatus(size_t slot, const toca::StatusPacket& s) {
    if (slot >= toca::kStatusSlots) return;
    portENTER_CRITICAL(&lock);
    slots[slot] = toca::SenderSlot{toca::SlotState::Reported, s.batteryPercent, s.millivolts};
    portEXIT_CRITICAL(&lock);
}

bool scrollHold(uint32_t nowMs) {
    portENTER_CRITICAL(&lock);
    const bool on = hold.active(nowMs);
    portEXIT_CRITICAL(&lock);
    return on;
}

void controlValue(uint32_t nowMs, uint8_t (&out)[toca::kControlValueSize]) {
    portENTER_CRITICAL(&lock);
    toca::encodeControlValue(hold.active(nowMs), reverse, senderMode, out);
    portEXIT_CRITICAL(&lock);
}

}  // namespace pc_channel

#endif  // TOCA_PC_CHANNEL
