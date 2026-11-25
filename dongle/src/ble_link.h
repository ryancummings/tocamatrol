// BLE side: the Tocamatrol GATT service, bonding rules and the pairing window
// (PROTOCOL.md "Bonding", ADR 0002).
#pragma once

#include <stdint.h>

#include "status_led.h"

namespace ble_link {
// Starts the BLE stack and advertising, with the pairing window open.
void begin(uint32_t nowMs);
// Call often (every loop): closes the pairing window and drops unencrypted links on time.
void tick(uint32_t nowMs);
void openPairingWindow(uint32_t nowMs);
// Disconnects, erases every bond, and opens the pairing window.
void forgetAllPhones(uint32_t nowMs);
LinkState state();
// Packets accepted since boot (for debug logging).
uint32_t packetsReceived();
// Milliseconds until the pairing window closes; 0 when it is closed.
uint32_t pairingWindowLeftMs(uint32_t nowMs);
// The dongle's name: the one a phone gave it, or "Tocamatrol A1B2". Valid after begin().
const char* name();
// Senders with a stored bond.
uint8_t bondedPhones();
// Senders connected, encrypted and accepted right now (0..hid_output::kMaxSenders).
uint8_t connectedSenders();
}  // namespace ble_link
