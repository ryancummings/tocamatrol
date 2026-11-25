// Optional vendor-defined HID status channel (compiled out when TOCA_PC_CHANNEL == 0).
#pragma once

#include <stddef.h>
#include <stdint.h>

#include "toca/packet.h"
#include "toca/pc_status.h"

namespace pc_channel {
#if TOCA_PC_CHANNEL
void begin();
void senderConnected(size_t slot);
void senderLeft(size_t slot);
void senderStatus(size_t slot, const toca::StatusPacket& s);
bool scrollHold(uint32_t nowMs);
void controlValue(uint32_t nowMs, uint8_t (&out)[toca::kControlValueSize]);
#else
inline void begin() {}
inline void senderConnected(size_t) {}
inline void senderLeft(size_t) {}
inline void senderStatus(size_t, const toca::StatusPacket&) {}
inline bool scrollHold(uint32_t) { return false; }
inline void controlValue(uint32_t, uint8_t (&out)[toca::kControlValueSize]) {
    out[0] = 0;
    out[1] = 0;
}
#endif
}  // namespace pc_channel
