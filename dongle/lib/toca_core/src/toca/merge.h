// Combines input from several connected senders (for example an iPhone and an iPad) into
// one USB mouse and keyboard ("Several senders" in PROTOCOL.md).
//
// Every packet carries its sender's whole button or key state, so each sender's state is
// kept apart. The PC sees the union: a button or modifier is held if any sender holds it,
// and the held keys are every sender's keys (at most 6). Movement and scroll pass through
// unchanged; senders' movement simply adds up over time.
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "toca/packet.h"

namespace toca {

template <size_t N>
class InputMerger {
   public:
    static constexpr size_t kSources = N;

    // A sender's pointer packet, turned into the packet the PC should see: the same
    // movement, with every sender's buttons.
    PointerPacket pointer(size_t source, const PointerPacket& p) {
        if (source < N) buttons_[source] = p.buttons;
        PointerPacket out = p;
        out.buttons = mergedButtons();
        return out;
    }

    // A sender's keyboard packet, turned into the full keyboard state the PC should see.
    KeyboardPacket keyboard(size_t source, const KeyboardPacket& k) {
        if (source < N) {
            modifiers_[source] = k.modifiers;
            memcpy(keys_[source], k.keys, 6);
        }
        KeyboardPacket out = mergedKeys();
        out.seq = k.seq;
        return out;
    }

    // A sender left: forget its state. Returns the pointer packet (no movement) and keyboard
    // state the PC should see now.
    void clear(size_t source, PointerPacket& pointerOut, KeyboardPacket& keysOut) {
        if (source < N) {
            buttons_[source] = 0;
            modifiers_[source] = 0;
            memset(keys_[source], 0, 6);
        }
        pointerOut = PointerPacket{0, mergedButtons(), 0, 0, 0, 0};
        keysOut = mergedKeys();
    }

    void clearAll() {
        memset(buttons_, 0, sizeof buttons_);
        memset(modifiers_, 0, sizeof modifiers_);
        memset(keys_, 0, sizeof keys_);
    }

    uint8_t mergedButtons() const {
        uint8_t b = 0;
        for (size_t i = 0; i < N; ++i) b |= buttons_[i];
        return b;
    }

    KeyboardPacket mergedKeys() const {
        KeyboardPacket out{};
        size_t n = 0;
        for (size_t s = 0; s < N; ++s) {
            out.modifiers |= modifiers_[s];
            for (size_t k = 0; k < 6; ++k) {
                const uint8_t key = keys_[s][k];
                if (key == 0) continue;
                bool dup = false;
                for (size_t j = 0; j < n; ++j) dup = dup || out.keys[j] == key;
                if (!dup && n < 6) out.keys[n++] = key;
            }
        }
        return out;
    }

   private:
    uint8_t buttons_[N] = {};
    uint8_t modifiers_[N] = {};
    uint8_t keys_[N][6] = {};
};

}  // namespace toca
