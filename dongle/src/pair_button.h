// The board's BOOT button: short press opens the pairing window, a 5 s hold forgets all phones.
#pragma once

#include <stdint.h>

enum class ButtonAction : uint8_t { None, ShortPress, LongHold };

namespace pair_button {
void begin();
// Call often (every loop). Returns an action at most once per press.
ButtonAction poll(uint32_t nowMs);
}  // namespace pair_button
