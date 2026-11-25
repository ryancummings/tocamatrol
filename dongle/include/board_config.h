// Per-board pins. Pick the board with a -DTOCA_BOARD_* flag in platformio.ini.
// To add a board: copy one block, change the pins, and add an env to platformio.ini.
#pragma once

#if defined(TOCA_BOARD_T_DONGLE_S3)
// LilyGO T-Dongle-S3. Pins from LilyGO's T-Dongle-S3 examples (examples/lcd/lcd.ino).
#define TOCA_BOARD_NAME "LilyGO T-Dongle-S3"
#define TOCA_LED_APA102 1
#define TOCA_LED_DATA_PIN 40
#define TOCA_LED_CLOCK_PIN 39
#define TOCA_BUTTON_PIN 0  // BOOT button, active low
// 0.96" ST7735 LCD, 160 x 80. It shows the status, so the bright RGB LED stays off.
#define TOCA_LCD_ST7735 1
#define TOCA_LCD_MOSI_PIN 3
#define TOCA_LCD_CLOCK_PIN 5
#define TOCA_LCD_CS_PIN 4
#define TOCA_LCD_DC_PIN 2
#define TOCA_LCD_RESET_PIN 1
#define TOCA_LCD_BACKLIGHT_PIN 38  // active low

#elif defined(TOCA_BOARD_XIAO_ESP32S3)
// Seeed XIAO ESP32-S3.
#define TOCA_BOARD_NAME "Seeed XIAO ESP32-S3"
#define TOCA_LED_GPIO 1
#define TOCA_LED_PIN 21  // user LED, active low
#define TOCA_LED_ACTIVE_LOW 1
#define TOCA_BUTTON_PIN 0  // BOOT button, active low

#elif defined(TOCA_BOARD_DEVKITC_S3)
// ESP32-S3-DevKitC-1 and its clones (ESP32-S3-WROOM-1, e.g. N16R8). Two USB-C ports:
// "USB" is the chip's own port and becomes the HID mouse + keyboard; "COM"/"UART" is a
// USB-serial bridge, used for flashing.
#define TOCA_BOARD_NAME "ESP32-S3-DevKitC-1"
#define TOCA_LED_WS2812 1
#define TOCA_LED_PIN 48  // RGB LED: GPIO 48 on v1.0 boards and most clones, 38 on v1.1
#define TOCA_BUTTON_PIN 0  // BOOT button, active low

#else
#error "Set a board: -DTOCA_BOARD_T_DONGLE_S3, _XIAO_ESP32S3 or _DEVKITC_S3"
#endif
