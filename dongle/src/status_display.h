// Status screen, on boards with one (the T-Dongle-S3's LCD). Does nothing on other boards.
#pragma once

#include <stdint.h>

#include "status_led.h"

namespace status_display {

struct Status {
    LinkState link;
    uint32_t pairingLeftMs;  // 0 when the pairing window is closed
    uint8_t phones;          // bonded senders
    uint8_t senders;         // connected and accepted right now
    bool pcListening;        // the PC has configured the USB interfaces
    const char* name;        // "Tocamatrol A1B2", as the phone lists it
};

void begin();
// Call often (every loop). Redraws only when what it shows has changed.
void show(const Status& status, uint32_t nowMs);

}  // namespace status_display
