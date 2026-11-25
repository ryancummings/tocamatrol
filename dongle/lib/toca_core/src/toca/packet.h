// Decoding of phone → dongle packets. Layout: ../../../../protocol/PROTOCOL.md.
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace toca {

constexpr uint8_t kProtocolVersion = 1;
constexpr uint8_t kTypePointer = 0;
constexpr size_t kPointerPacketSize = 9;
constexpr size_t kPointerExtendedPacketSize = 11;
constexpr uint8_t kTypeKeyboard = 1;
constexpr size_t kKeyboardPacketSize = 9;
constexpr uint8_t kTypeStatus = 2;
constexpr size_t kStatusPacketSize = 4;
constexpr uint8_t kBatteryUnknown = 0xFF;
constexpr uint8_t kTypeScrollRate = 3;
constexpr size_t kScrollRatePacketSize = 4;

struct PointerPacket {
    uint8_t seq;
    uint8_t buttons;  // bit 0 left, bit 1 right, bit 2 middle: buttons held now
    int16_t dx;       // positive is right
    int16_t dy;       // positive is down
    int16_t vscroll;  // whole vertical scroll ticks; positive scrolls up
    int16_t hscroll;  // whole horizontal scroll ticks; positive scrolls right
};

struct KeyboardPacket {
    uint8_t seq;
    uint8_t modifiers;  // boot keyboard modifier bits: modifiers held now
    uint8_t keys[6];    // Keyboard page usage IDs held now; 0 is an empty slot
};

// Optional sender status packet (when TOCA_PC_CHANNEL is enabled).
struct StatusPacket {
    uint8_t batteryPercent;  // 0..100, or kBatteryUnknown
    uint16_t millivolts;     // battery voltage; 0 if unknown
};

// Optional continuous scroll-rate packet (when TOCA_PC_CHANNEL is enabled).
struct ScrollRatePacket {
    uint8_t seq;
    int16_t rateX16;  // steps per second x 16; positive scrolls up
};

enum class DecodeStatus {
    Pointer,
    Keyboard,
    Status,
    ScrollRate,
    TooShort,
    UnknownVersion,
    ReservedType,
};

struct Decoded {
    DecodeStatus status;
    PointerPacket pointer;        // valid only when status is Pointer
    KeyboardPacket keyboard;      // valid only when status is Keyboard
    StatusPacket senderStatus;    // valid only when status is Status
    ScrollRatePacket scrollRate;  // valid only when status is ScrollRate
};

Decoded decode(const uint8_t* data, size_t len);

}  // namespace toca
