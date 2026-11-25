#include "hid_output.h"

#include <Arduino.h>
#include <USB.h>
#include <USBHIDKeyboard.h>
#include <USBHIDMouse.h>
#include <tusb.h>

#include "log.h"
#include "pc_channel.h"
#include "toca/merge.h"
#include "toca/report_plan.h"
#if TOCA_PC_CHANNEL
#include "toca/scroll_pacer.h"
#endif

namespace hid_output {

namespace {

struct Command {
    enum class Kind : uint8_t {
        Pointer,
        Keyboard,
        Release,
        ReleaseAll,
#if TOCA_PC_CHANNEL
        Rate,
        StopRates,
#endif
    } kind;
    uint8_t source;
    toca::PointerPacket packet;
    toca::KeyboardPacket keys;
#if TOCA_PC_CHANNEL
    int16_t rateX16;
    uint32_t atUs;
#endif
};

constexpr UBaseType_t kQueueLength = 32;

USBHIDMouse mouse;
USBHIDKeyboard keyboard;
QueueHandle_t queue = nullptr;

// Reports only go out while the PC is listening; otherwise each send would wait out its timeout.
bool usbReady() { return tud_mounted() && !tud_suspended(); }

void send(const toca::MouseReport& r) {
    if (!usbReady()) return;
    hid_mouse_report_t report = {};
    report.buttons = r.buttons;
    report.x = r.x;
    report.y = r.y;
    report.wheel = r.wheel;
    report.pan = r.pan;
    mouse.sendReport(report);  // returns once the PC has polled it (1 ms interval)
}

void sendKeys(const toca::KeyboardPacket& k) {
    if (!usbReady()) return;
    KeyReport report = {};
    report.modifiers = k.modifiers;
    memcpy(report.keys, k.keys, sizeof report.keys);
    keyboard.sendReport(&report);
}

#if TOCA_DEBUG
// Each packet type counts its own seq (PROTOCOL.md).
void checkSeq(const char* type, int& last, uint8_t seq) {
    if (last >= 0 && seq != static_cast<uint8_t>(last + 1)) LOG("hid: %s seq gap %d -> %u\n", type, last, seq);
    last = seq;
}
#endif

// Only the HID task touches them.
toca::InputMerger<kMaxSenders> merger;
#if TOCA_PC_CHANNEL
toca::ScrollPacer<kMaxSenders> pacer;
uint32_t nowUs() { return static_cast<uint32_t>(esp_timer_get_time()); }
#endif

void hidTask(void*) {
    uint8_t held = 0;
#if TOCA_DEBUG
    int lastPointerSeq[kMaxSenders] = {-1, -1, -1};
    int lastKeyboardSeq[kMaxSenders] = {-1, -1, -1};
#endif
    Command cmd;
    for (;;) {
#if TOCA_PC_CHANNEL
        const bool got = xQueueReceive(queue, &cmd, pacer.active() ? 1 : portMAX_DELAY) == pdTRUE;
        if (pacer.active()) {
            int32_t steps = pacer.advance(nowUs());
            while (steps != 0) {
                const int8_t step = steps > 0 ? 1 : -1;
                send(toca::MouseReport{held, 0, 0, step, 0});
                steps -= step;
            }
        }
#else
        const bool got = xQueueReceive(queue, &cmd, portMAX_DELAY) == pdTRUE;
#endif
        if (!got) continue;
#if TOCA_PC_CHANNEL
        if (cmd.kind == Command::Kind::Rate) {
            pacer.setRate(cmd.source, cmd.rateX16, cmd.atUs);
            continue;
        }
        if (cmd.kind == Command::Kind::StopRates) {
            pacer.stopAll();
            continue;
        }
#endif
        if (cmd.kind == Command::Kind::ReleaseAll) {
            merger.clearAll();
#if TOCA_PC_CHANNEL
            pacer.stopAll();
#endif
            held = toca::planReports(held, toca::PointerPacket{}, send);
            if (usbReady()) keyboard.releaseAll();
            LOG("hid: released all\n");
            continue;
        }
        if (cmd.kind == Command::Kind::Release) {
            toca::PointerPacket p;
            toca::KeyboardPacket k;
            merger.clear(cmd.source, p, k);
#if TOCA_PC_CHANNEL
            pacer.stop(cmd.source);
#endif
            held = toca::planReports(held, p, send);
            sendKeys(k);
#if TOCA_DEBUG
            if (cmd.source < kMaxSenders) lastPointerSeq[cmd.source] = lastKeyboardSeq[cmd.source] = -1;
#endif
            LOG("hid: released sender %u\n", cmd.source);
            continue;
        }
        if (cmd.kind == Command::Kind::Keyboard) {
#if TOCA_DEBUG
            if (cmd.source < kMaxSenders) checkSeq("keyboard", lastKeyboardSeq[cmd.source], cmd.keys.seq);
#endif
            sendKeys(merger.keyboard(cmd.source, cmd.keys));
            continue;
        }
#if TOCA_DEBUG
        if (cmd.source < kMaxSenders) checkSeq("pointer", lastPointerSeq[cmd.source], cmd.packet.seq);
#endif
        held = toca::planReports(held, merger.pointer(cmd.source, cmd.packet), send);
    }
}

}  // namespace

void begin() {
    queue = xQueueCreate(kQueueLength, sizeof(Command));
    mouse.begin();
    keyboard.begin();
#if TOCA_PC_CHANNEL
    pc_channel::begin();
#endif
    USB.manufacturerName("Tocamatrol");
    USB.productName("Tocamatrol");
    const bool started = USB.begin();
    (void)started;
    LOG("hid: usb %s\n", started ? "started" : "FAILED to start");
    // Above the Arduino loop (priority 1), so reports go out as soon as a packet lands.
    xTaskCreatePinnedToCore(hidTask, "hid", 4096, nullptr, 5, nullptr, ARDUINO_RUNNING_CORE);
}

bool pcListening() { return usbReady(); }

bool submit(size_t source, const toca::PointerPacket& packet) {
    Command cmd{};
    cmd.kind = Command::Kind::Pointer;
    cmd.source = static_cast<uint8_t>(source);
    cmd.packet = packet;
    return xQueueSend(queue, &cmd, 0) == pdTRUE;
}

bool submit(size_t source, const toca::KeyboardPacket& packet) {
    Command cmd{};
    cmd.kind = Command::Kind::Keyboard;
    cmd.source = static_cast<uint8_t>(source);
    cmd.keys = packet;
    return xQueueSend(queue, &cmd, 0) == pdTRUE;
}

void release(size_t source) {
    Command cmd{};
    cmd.kind = Command::Kind::Release;
    cmd.source = static_cast<uint8_t>(source);
    xQueueSend(queue, &cmd, pdMS_TO_TICKS(50));
}

void releaseAll() {
    Command cmd{};
    cmd.kind = Command::Kind::ReleaseAll;
    xQueueSend(queue, &cmd, pdMS_TO_TICKS(50));
}

#if TOCA_PC_CHANNEL
bool submitRate(size_t source, int16_t rateX16) {
    Command cmd{};
    cmd.kind = Command::Kind::Rate;
    cmd.source = static_cast<uint8_t>(source);
    cmd.rateX16 = rateX16;
    cmd.atUs = nowUs();
    return xQueueSend(queue, &cmd, 0) == pdTRUE;
}

void stopRates() {
    Command cmd{};
    cmd.kind = Command::Kind::StopRates;
    xQueueSend(queue, &cmd, pdMS_TO_TICKS(50));
}
#endif

}  // namespace hid_output
