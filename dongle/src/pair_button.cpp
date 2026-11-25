#include "pair_button.h"

#include <Arduino.h>

#include "board_config.h"

namespace pair_button {

namespace {
constexpr uint32_t kDebounceMs = 30;
constexpr uint32_t kShortPressMaxMs = 1000;
constexpr uint32_t kLongHoldMs = 5000;

bool down = false;
bool longFired = false;
uint32_t changedAt = 0;
}  // namespace

void begin() { pinMode(TOCA_BUTTON_PIN, INPUT_PULLUP); }

ButtonAction poll(uint32_t nowMs) {
    const bool pressed = digitalRead(TOCA_BUTTON_PIN) == LOW;
    if (pressed != down && nowMs - changedAt >= kDebounceMs) {
        down = pressed;
        const uint32_t heldFor = nowMs - changedAt;
        changedAt = nowMs;
        if (!down) {
            const bool wasLong = longFired;
            longFired = false;
            if (!wasLong && heldFor <= kShortPressMaxMs) return ButtonAction::ShortPress;
        }
        return ButtonAction::None;
    }
    if (down && !longFired && nowMs - changedAt >= kLongHoldMs) {
        longFired = true;
        return ButtonAction::LongHold;
    }
    return ButtonAction::None;
}

}  // namespace pair_button
