// Optional rate-based wheel pacer (used when TOCA_PC_CHANNEL is enabled).
// Pure logic: time comes in as microseconds.
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace toca {

// A rate expires if not refreshed within this duration.
constexpr uint32_t kRateExpiryUs = 100000;
constexpr float kRateStartPhase = 1.0f;
constexpr uint32_t kRestartMemoryUs = 250000;

template <size_t N>
class ScrollPacer {
   public:
    // rateX16: steps per second x 16; positive scrolls up, as vscroll does.
    void setRate(size_t source, int16_t rateX16, uint32_t nowUs) {
        if (source >= N) return;
        Lane& l = lanes_[source];
        const float rate = rateX16 / 16.0f;
        if (rate == 0.0f) {
            if (l.running) {
                l.running = false;
                l.stoppedUs = nowUs;
            }
            return;
        }
        const bool turned = l.rate != 0.0f && (rate > 0) != (l.rate > 0);
        if (!l.running || turned) {
            const bool resume = !l.running && !turned && l.rate != 0.0f &&
                                nowUs - l.stoppedUs < kRestartMemoryUs;
            if (!resume) l.phase = kRateStartPhase;
            l.lastUs = nowUs;
            l.running = true;
        }
        l.rate = rate;
        l.updatedUs = nowUs;
    }

    void stop(size_t source) {
        if (source < N) lanes_[source] = Lane{};
    }

    void stopAll() {
        for (auto& l : lanes_) l = Lane{};
    }

    bool active() const {
        for (const auto& l : lanes_)
            if (l.running) return true;
        return false;
    }

    // Steps due since the last call, summed over senders (positive scrolls up).
    int32_t advance(uint32_t nowUs) {
        int32_t steps = 0;
        for (auto& l : lanes_) {
            if (!l.running) continue;
            if (nowUs - l.updatedUs > kRateExpiryUs) {
                l = Lane{};
                continue;
            }
            const float dt = (nowUs - l.lastUs) * 1e-6f;
            l.lastUs = nowUs;
            const float mag = l.rate > 0 ? l.rate : -l.rate;
            l.phase += mag * dt;
            while (l.phase >= 1.0f) {
                l.phase -= 1.0f;
                steps += l.rate > 0 ? 1 : -1;
            }
        }
        return steps;
    }

   private:
    struct Lane {
        bool running = false;
        float rate = 0;
        float phase = 0;
        uint32_t stoppedUs = 0;
        uint32_t lastUs = 0;
        uint32_t updatedUs = 0;
    };
    Lane lanes_[N];
};

}  // namespace toca
