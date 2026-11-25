// Status LED: shows whether the dongle is advertising, open for pairing, or in use. On a board
// with a screen it is steady and dim; elsewhere it blinks.
#pragma once

#include <stdint.h>

enum class LinkState : uint8_t {
    Advertising,    // waiting for a bonded phone
    PairingWindow,  // a new phone may pair
    Securing,       // a phone is connected but not yet encrypted and accepted
    Connected,      // a bonded phone is connected and may send input
};

namespace status_led {
void begin();
// Call often (every loop). Draws the pattern for `state` at time `nowMs`.
void show(LinkState state, uint32_t nowMs);
}  // namespace status_led
