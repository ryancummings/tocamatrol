// Tocamatrol dongle: BLE packets from the phone in, USB HID mouse + keyboard reports out.
// See ../protocol/PROTOCOL.md.
#include <Arduino.h>

#include "ble_link.h"
#include "board_config.h"
#include "hid_output.h"
#include "log.h"
#include "pair_button.h"
#include "status_display.h"
#include "status_led.h"

void setup() {
#if TOCA_DEBUG
    Serial.begin(115200);
#endif
    LOG("tocamatrol %d.%d on %s\n", FW_VERSION_MAJOR, FW_VERSION_MINOR, TOCA_BOARD_NAME);
    hid_output::begin();
    LOG("setup: usb hid started\n");
    status_led::begin();
    status_display::begin();
    pair_button::begin();
    LOG("setup: led and button ready\n");
    ble_link::begin(millis());
    LOG("setup: done\n");
}

void loop() {
    const uint32_t now = millis();
    switch (pair_button::poll(now)) {
        case ButtonAction::ShortPress:
            ble_link::openPairingWindow(now);
            break;
        case ButtonAction::LongHold:
            ble_link::forgetAllPhones(now);
            break;
        case ButtonAction::None:
            break;
    }
    ble_link::tick(now);
#if TOCA_DEBUG
    static uint32_t lastReport = 0;
    static bool lastListening = false;
    const bool listening = hid_output::pcListening();
    if (listening != lastListening || now - lastReport > 2000) {
        static const char* const kStates[] = {"advertising", "pairing window", "securing", "connected"};
        LOG("status: usb pc %s, ble %s, %lu packets\n", listening ? "listening" : "not listening",
            kStates[static_cast<int>(ble_link::state())], static_cast<unsigned long>(ble_link::packetsReceived()));
        lastListening = listening;
        lastReport = now;
    }
#endif
    status_led::show(ble_link::state(), now);
    status_display::show({ble_link::state(), ble_link::pairingWindowLeftMs(now), ble_link::bondedPhones(),
                          ble_link::connectedSenders(),
                          hid_output::pcListening(), ble_link::name()},
                         now);
    delay(5);
}
