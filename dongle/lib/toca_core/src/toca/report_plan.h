// Turns one pointer packet into the USB HID mouse reports that carry it
// ("Report split" and "Button order" in PROTOCOL.md).
#pragma once

#include <stdint.h>

#include "toca/packet.h"

namespace toca {

// One relative mouse report, matching TinyUSB hid_mouse_report_t.
struct MouseReport {
    uint8_t buttons;
    int8_t x;
    int8_t y;
    int8_t wheel;
    int8_t pan;
};

constexpr int32_t kMaxStep = 127;
// Scroll goes out one wheel/pan tick per report, as a physical mouse wheel sends it.
// The USB host polls every 1 ms, so 3 steps take 3 ms.
constexpr int32_t kMaxWheelStep = 1;

// Takes the next step of at most `maxStep` from `remaining`.
inline int8_t takeStep(int32_t& remaining, int32_t maxStep = kMaxStep) {
    int32_t step = remaining > maxStep ? maxStep : (remaining < -maxStep ? -maxStep : remaining);
    remaining -= step;
    return static_cast<int8_t>(step);
}

// Calls emit(const MouseReport&) once per report, in send order.
// `held` is the button state the PC last saw; returns the state it sees afterwards.
template <typename Emit>
uint8_t planReports(uint8_t held, const PointerPacket& p, Emit&& emit) {
    // New presses go out first, so a drag starts where the pointer was.
    const uint8_t during = held | p.buttons;
    if (during != held) {
        emit(MouseReport{during, 0, 0, 0, 0});
    }

    int32_t x = p.dx, y = p.dy, wheel = p.vscroll, pan = p.hscroll;
    while (x != 0 || y != 0 || wheel != 0 || pan != 0) {
        MouseReport r{during, 0, 0, 0, 0};
        r.x = takeStep(x);
        r.y = takeStep(y);
        r.wheel = takeStep(wheel, kMaxWheelStep);
        r.pan = takeStep(pan, kMaxWheelStep);
        emit(r);
    }

    // Releases go out last, so a drop happens where the pointer ended.
    if (p.buttons != during) {
        emit(MouseReport{p.buttons, 0, 0, 0, 0});
    }
    return p.buttons;
}

}  // namespace toca
