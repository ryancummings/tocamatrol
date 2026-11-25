#include "toca/packet.h"

namespace toca {

static int16_t readI16(const uint8_t* p) {
    return static_cast<int16_t>(static_cast<uint16_t>(p[0] | (p[1] << 8)));
}

Decoded decode(const uint8_t* data, size_t len) {
    Decoded d{};
    if (len == 0) {
        d.status = DecodeStatus::TooShort;
        return d;
    }
    const uint8_t version = data[0] & 0x0F;
    const uint8_t type = data[0] >> 4;
    if (version != kProtocolVersion) {
        d.status = DecodeStatus::UnknownVersion;
        return d;
    }
    if (type == kTypeKeyboard) {
        if (len < kKeyboardPacketSize) {
            d.status = DecodeStatus::TooShort;
            return d;
        }
        d.keyboard.seq = data[1];
        d.keyboard.modifiers = data[2];
        for (size_t i = 0; i < 6; ++i) d.keyboard.keys[i] = data[3 + i];
        d.status = DecodeStatus::Keyboard;
        return d;
    }
    if (type == kTypeStatus) {
        if (len < kStatusPacketSize) {
            d.status = DecodeStatus::TooShort;
            return d;
        }
        d.senderStatus.batteryPercent = data[1] <= 100 ? data[1] : kBatteryUnknown;
        d.senderStatus.millivolts = static_cast<uint16_t>(data[2] | (data[3] << 8));
        d.status = DecodeStatus::Status;
        return d;
    }
    if (type == kTypeScrollRate) {
        if (len < kScrollRatePacketSize) {
            d.status = DecodeStatus::TooShort;
            return d;
        }
        d.scrollRate.seq = data[1];
        d.scrollRate.rateX16 = readI16(data + 2);
        d.status = DecodeStatus::ScrollRate;
        return d;
    }
    if (type != kTypePointer) {
        d.status = DecodeStatus::ReservedType;
        return d;
    }
    if (len < kPointerPacketSize) {
        d.status = DecodeStatus::TooShort;
        return d;
    }
    d.pointer.seq = data[1];
    d.pointer.buttons = data[2];
    d.pointer.dx = readI16(data + 3);
    d.pointer.dy = readI16(data + 5);
    d.pointer.vscroll = readI16(data + 7);
    d.pointer.hscroll = len >= kPointerExtendedPacketSize ? readI16(data + 9) : 0;
    d.status = DecodeStatus::Pointer;
    return d;
}

}  // namespace toca
