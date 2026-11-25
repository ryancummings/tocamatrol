#include "status_display.h"

#include "board_config.h"

#if TOCA_LCD_ST7735

#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <Arduino.h>
#include <SPI.h>

#include <string.h>

namespace status_display {

namespace {

constexpr int16_t kWidth = 160;
constexpr int16_t kHeight = 80;
// Backlight duty out of 255: readable without glaring.
constexpr uint8_t kBrightness = 40;

// Muted colours on black, so the screen is quiet at the edge of vision.
constexpr uint16_t rgb(uint8_t r, uint8_t g, uint8_t b) {
    return static_cast<uint16_t>(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}
constexpr uint16_t kText = rgb(200, 200, 200);
constexpr uint16_t kDim = rgb(110, 110, 110);
constexpr uint16_t kGreen = rgb(90, 190, 110);
constexpr uint16_t kAmber = rgb(230, 160, 60);
constexpr uint16_t kRed = rgb(220, 90, 80);

Adafruit_ST7735 lcd(&SPI, TOCA_LCD_CS_PIN, TOCA_LCD_DC_PIN, TOCA_LCD_RESET_PIN);
// Drawn off screen and sent in one go, so a redraw never flickers.
GFXcanvas16 canvas(kWidth, kHeight);

struct Shown {
    char title[16];
    char detail[24];
    char footer[24];
    uint16_t color;
};
Shown shown{};

Shown describe(const Status& s) {
    Shown v{};
    switch (s.link) {
        case LinkState::Connected:
            strcpy(v.title, "Connected");
            v.color = kGreen;
            break;
        case LinkState::Securing:
            strcpy(v.title, "Pairing...");
            v.color = kAmber;
            break;
        case LinkState::PairingWindow:
            strcpy(v.title, "Pair now");
            v.color = kAmber;
            break;
        case LinkState::Advertising:
            strcpy(v.title, "Waiting");
            v.color = kText;
            break;
    }
    if (s.link == LinkState::Connected && s.pairingLeftMs > 0) {
        snprintf(v.detail, sizeof v.detail, "%u linked, pair %lus", s.senders,
                 static_cast<unsigned long>((s.pairingLeftMs + 999) / 1000));
    } else if (s.link == LinkState::Connected && s.senders > 1) {
        snprintf(v.detail, sizeof v.detail, "%u devices linked", s.senders);
    } else if (s.link == LinkState::PairingWindow) {
        snprintf(v.detail, sizeof v.detail, "open %lu s", static_cast<unsigned long>((s.pairingLeftMs + 999) / 1000));
    } else if (s.link == LinkState::Advertising) {
        snprintf(v.detail, sizeof v.detail, s.phones == 1 ? "1 phone paired" : "%u phones paired", s.phones);
    }
    if (!s.pcListening) {
        strcpy(v.footer, "PC not ready");
    } else {
        // The name the phone lists, so the right dongle can be picked in the app.
        snprintf(v.footer, sizeof v.footer, "%s  v%d.%d", s.name, FW_VERSION_MAJOR, FW_VERSION_MINOR);
    }
    return v;
}

void draw(const Shown& v, bool pcListening) {
    canvas.fillScreen(0);
    canvas.setTextWrap(false);
    canvas.setTextSize(2);
    canvas.setTextColor(v.color);
    canvas.setCursor(6, 10);
    canvas.print(v.title);
    canvas.setTextSize(1);
    canvas.setTextColor(kText);
    canvas.setCursor(6, 36);
    canvas.print(v.detail);
    canvas.setTextColor(pcListening ? kDim : kRed);
    canvas.setCursor(6, 64);
    canvas.print(v.footer);
    lcd.drawRGBBitmap(0, 0, canvas.getBuffer(), kWidth, kHeight);
}

}  // namespace

void begin() {
    // Backlight off until the first frame is drawn, so power-up shows no noise.
    ledcAttach(TOCA_LCD_BACKLIGHT_PIN, 1000, 8);
    ledcWrite(TOCA_LCD_BACKLIGHT_PIN, 255);
    SPI.begin(TOCA_LCD_CLOCK_PIN, -1, TOCA_LCD_MOSI_PIN, TOCA_LCD_CS_PIN);
    lcd.initR(INITR_MINI160x80_PLUGIN);
    lcd.setRotation(3);
    lcd.fillScreen(0);
    ledcWrite(TOCA_LCD_BACKLIGHT_PIN, 255 - kBrightness);  // active low
}

void show(const Status& status, uint32_t) {
    const Shown v = describe(status);
    if (memcmp(&v, &shown, sizeof v) == 0) return;
    shown = v;
    draw(v, status.pcListening);
}

}  // namespace status_display

#else

namespace status_display {
void begin() {}
void show(const Status&, uint32_t) {}
}  // namespace status_display

#endif
