// USB side: a composite HID mouse (with vertical wheel + horizontal pan) + keyboard, fed from a queue.
// BLE callbacks only enqueue; a dedicated task sends the reports, so a slow or
// absent USB host never blocks the BLE stack.
#pragma once

#include <stddef.h>

#include "toca/packet.h"

namespace hid_output {
// Senders that may be connected at once (for example an iPhone and an iPad). NimBLE's
// precompiled limit is 3 connections.
constexpr size_t kMaxSenders = 3;

// Registers the HID interfaces and starts USB. Call once, early in setup().
void begin();
// The PC has configured the HID interfaces and is not suspended.
bool pcListening();
// Queues a decoded pointer packet from sender `source` (0..kMaxSenders-1). Safe from any
// task. Returns false if the queue is full.
bool submit(size_t source, const toca::PointerPacket& packet);
// Queues a decoded keyboard packet, in order with pointer packets. Same rules as above.
bool submit(size_t source, const toca::KeyboardPacket& packet);
// Queues "release what this sender holds" (it disconnected), behind queued packets.
// Other senders' buttons and keys stay held.
void release(size_t source);
// Queues "release every button and key", behind any packets already queued.
void releaseAll();
#if TOCA_PC_CHANNEL
bool submitRate(size_t source, int16_t rateX16);
void stopRates();
#endif
}  // namespace hid_output
