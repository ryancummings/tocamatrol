#include "toca/advert.h"

#include <stdio.h>

namespace toca {

void advertData(bool pairingWindowOpen, uint8_t out[kAdvertDataSize]) {
    out[0] = 0xFF;
    out[1] = 0xFF;
    out[2] = pairingWindowOpen ? 0x01 : 0x00;
}

void dongleName(const uint8_t address[6], char out[kDongleNameSize]) {
    snprintf(out, kDongleNameSize, "Tocamatrol %02X%02X", address[4], address[5]);
}

size_t cleanName(const uint8_t* in, size_t len, char out[kMaxNameLength + 1]) {
    size_t start = 0;
    while (start < len && in[start] == ' ') ++start;
    size_t n = 0;
    for (size_t i = start; i < len && n < kMaxNameLength; ++i) {
        out[n++] = in[i] >= 0x20 && in[i] <= 0x7E ? static_cast<char>(in[i]) : '?';
    }
    while (n > 0 && out[n - 1] == ' ') --n;
    out[n] = '\0';
    return n;
}

}  // namespace toca
