// Serial logging, compiled in only for the *-debug environments (ADR 0003).
#pragma once

#include <Arduino.h>

#if TOCA_DEBUG
#define LOG(...) Serial.printf(__VA_ARGS__)
#else
#define LOG(...) \
    do {         \
    } while (0)
#endif
