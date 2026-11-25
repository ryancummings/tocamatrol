// What the dongle advertises (PROTOCOL.md "Advertising").
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace toca {

constexpr size_t kAdvertDataSize = 3;
// "Tocamatrol 566D" and its terminator.
constexpr size_t kDongleNameSize = 16;
// The longest name a phone can give the dongle (PROTOCOL.md "Name characteristic").
constexpr size_t kMaxNameLength = 20;

// Manufacturer data: company ID 0xFFFF, then the flags byte (bit 0: pairing window open).
void advertData(bool pairingWindowOpen, uint8_t out[kAdvertDataSize]);
// The local name from the Bluetooth address, given most significant byte first, as printed.
void dongleName(const uint8_t address[6], char out[kDongleNameSize]);
// A name written by a phone, cleaned: spaces trimmed, bytes outside printable ASCII made '?',
// at most kMaxNameLength bytes. Returns its length; 0 means "use the default name".
size_t cleanName(const uint8_t* in, size_t len, char out[kMaxNameLength + 1]);

}  // namespace toca
