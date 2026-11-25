#include "status_led.h"

#include <Arduino.h>

#include "board_config.h"

namespace status_led {

namespace {

struct Rgb {
    uint8_t r, g, b;
};

#if TOCA_LED_APA102
// One APA102 pixel, bit-banged: start frame, one LED frame, end frame.
void shiftOut8(uint8_t v) {
    for (int bit = 7; bit >= 0; --bit) {
        digitalWrite(TOCA_LED_DATA_PIN, (v >> bit) & 1);
        digitalWrite(TOCA_LED_CLOCK_PIN, HIGH);
        digitalWrite(TOCA_LED_CLOCK_PIN, LOW);
    }
}

#if TOCA_LCD_ST7735
// The screen is the main display; the LED is a dim hint seen from the back of the stick.
constexpr uint8_t kGlobalBrightness = 1;
#else
constexpr uint8_t kGlobalBrightness = 4;  // of 31: visible, not glaring
#endif

void write(Rgb c) {
    for (int i = 0; i < 4; ++i) shiftOut8(0x00);
    shiftOut8(0xE0 | kGlobalBrightness);
    shiftOut8(c.b);
    shiftOut8(c.g);
    shiftOut8(c.r);
    for (int i = 0; i < 4; ++i) shiftOut8(0xFF);
}
#elif TOCA_LED_WS2812
void write(Rgb c) {
    // Scaled down like the APA102: visible, not glaring.
    rgbLedWrite(TOCA_LED_PIN, c.r / 16, c.g / 16, c.b / 16);
}
#else
void write(Rgb c) {
    bool on = c.r || c.g || c.b;
#if TOCA_LED_ACTIVE_LOW
    on = !on;
#endif
    digitalWrite(TOCA_LED_PIN, on ? HIGH : LOW);
}
#endif

constexpr Rgb kOff{0, 0, 0};
constexpr Rgb kBlue{0, 0, 255};
constexpr Rgb kAmber{255, 120, 0};
constexpr Rgb kGreen{0, 255, 0};

bool sameColor(Rgb a, Rgb b) { return a.r == b.r && a.g == b.g && a.b == b.b; }

Rgb last{1, 1, 1};  // forces the first write

}  // namespace

void begin() {
#if TOCA_LED_APA102
    pinMode(TOCA_LED_DATA_PIN, OUTPUT);
    pinMode(TOCA_LED_CLOCK_PIN, OUTPUT);
    digitalWrite(TOCA_LED_CLOCK_PIN, LOW);
#elif !TOCA_LED_WS2812
    pinMode(TOCA_LED_PIN, OUTPUT);
#endif
    write(kOff);
}

void show(LinkState state, uint32_t nowMs) {
#if TOCA_LCD_ST7735
    // With a screen, the LED is steady and dim, one colour per state.
    (void)nowMs;
    constexpr Rgb kDimBlue{0, 0, 48};
    constexpr Rgb kDimAmber{64, 24, 0};
    constexpr Rgb kDimGreen{0, 48, 0};
    Rgb c = kDimBlue;
    switch (state) {
        case LinkState::Advertising:
            c = kDimBlue;
            break;
        case LinkState::PairingWindow:
        case LinkState::Securing:
            c = kDimAmber;
            break;
        case LinkState::Connected:
            c = kDimGreen;
            break;
    }
#else
    Rgb c = kOff;
    switch (state) {
        case LinkState::Advertising:  // short blue flash once a second
            c = (nowMs % 1000) < 80 ? kBlue : kOff;
            break;
        case LinkState::PairingWindow:  // amber, fast blink
            c = (nowMs % 250) < 125 ? kAmber : kOff;
            break;
        case LinkState::Securing:  // green, fast blink
            c = (nowMs % 250) < 125 ? kGreen : kOff;
            break;
        case LinkState::Connected:  // steady green
            c = kGreen;
            break;
    }
#endif
    if (!sameColor(c, last)) {
        write(c);
        last = c;
    }
}

}  // namespace status_led
