// Optional vendor-defined HID status channel (compiled out when TOCA_PC_CHANNEL == 0).
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "toca/packet.h"

namespace toca {

constexpr uint8_t kStatusReportId = 0x10;   // feature, dongle → PC
constexpr uint8_t kControlReportId = 0x11;  // feature, PC → dongle
constexpr size_t kPcReportSize = 15;        // bytes after the report ID, both reports
constexpr uint8_t kPcLayoutVersion = 1;
// A scroll hold the PC stops refreshing ends on its own after this timeout.
constexpr uint32_t kScrollHoldTimeoutMs = 2000;
constexpr size_t kStatusSlots = 3;

enum class SlotState : uint8_t { Empty = 0, Connected = 1, Reported = 2 };

struct SenderSlot {
    SlotState state = SlotState::Empty;
    uint8_t batteryPercent = kBatteryUnknown;
    uint16_t millivolts = 0;
};

// Status report payload: version, flags (bit 0 scroll hold), senders connected, then
// per slot: state, battery %, millivolts (u16 LE).
inline void encodeStatusReport(const SenderSlot (&slots)[kStatusSlots], bool scrollHold,
                               uint8_t (&out)[kPcReportSize]) {
    memset(out, 0, sizeof out);
    out[0] = kPcLayoutVersion;
    out[1] = scrollHold ? 0x01 : 0x00;
    uint8_t connected = 0;
    for (size_t i = 0; i < kStatusSlots; ++i) {
        const SenderSlot& s = slots[i];
        connected += s.state != SlotState::Empty;
        uint8_t* p = out + 3 + i * 4;
        p[0] = static_cast<uint8_t>(s.state);
        p[1] = s.state == SlotState::Reported ? s.batteryPercent : kBatteryUnknown;
        const uint16_t mv = s.state == SlotState::Reported ? s.millivolts : 0;
        p[2] = static_cast<uint8_t>(mv & 0xFF);
        p[3] = static_cast<uint8_t>(mv >> 8);
    }
    out[2] = connected;
}

enum class SenderMode : uint8_t { Tilt = 0, RotateJog = 1, RotateRate = 2 };

struct Control {
    bool scrollHold = false;
    bool reverse = false;
    uint8_t senderMode = 0;
};

// Control report payload: version, flags (bit 0 scroll hold, bit 1 reverse), sender mode.
// Accepts the payload with or without the leading report ID.
inline bool decodeControlReport(const uint8_t* data, size_t len, Control& c) {
    if (len == kPcReportSize + 1 && data[0] == kControlReportId) {
        ++data;
        --len;
    }
    if (len < 2 || data[0] != kPcLayoutVersion) return false;
    c.scrollHold = (data[1] & 0x01) != 0;
    c.reverse = (data[1] & 0x02) != 0;
    c.senderMode = len >= 3 ? data[2] : 0;
    return true;
}

constexpr size_t kControlValueSize = 2;
inline void encodeControlValue(bool scrollHold, bool reverse, uint8_t senderMode,
                               uint8_t (&out)[kControlValueSize]) {
    out[0] = (scrollHold ? 0x01 : 0x00) | (reverse ? 0x02 : 0x00);
    out[1] = senderMode;
}

class ScrollHold {
   public:
    void set(bool on, uint32_t nowMs) {
        on_ = on;
        setAt_ = nowMs;
    }
    bool active(uint32_t nowMs) const { return on_ && nowMs - setAt_ < kScrollHoldTimeoutMs; }

   private:
    bool on_ = false;
    uint32_t setAt_ = 0;
};

}  // namespace toca
