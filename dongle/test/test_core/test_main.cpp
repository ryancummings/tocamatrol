// Logic tests for lib/toca_core. Run with `pio test -e native`.
// Expected bytes come from ../protocol/PROTOCOL.md, not from the decoder.
#include <unity.h>

#include <string.h>

#include <vector>

#include "toca/advert.h"
#include "toca/merge.h"
#include "toca/packet.h"
#include "toca/pc_status.h"
#include "toca/report_plan.h"
#include "toca/scroll_pacer.h"

using namespace toca;

void setUp() {}
void tearDown() {}

static void decodes_the_protocol_example_pointer_packet() {
    // PROTOCOL.md (11-byte): left held, right 3, up 2, vscroll -1, hscroll +2, seq 7.
    const uint8_t bytes[] = {0x01, 0x07, 0x01, 0x03, 0x00, 0xFE, 0xFF, 0xFF, 0xFF, 0x02, 0x00};

    Decoded d = decode(bytes, sizeof bytes);

    TEST_ASSERT_EQUAL(DecodeStatus::Pointer, d.status);
    TEST_ASSERT_EQUAL_UINT8(7, d.pointer.seq);
    TEST_ASSERT_EQUAL_UINT8(0x01, d.pointer.buttons);
    TEST_ASSERT_EQUAL_INT16(3, d.pointer.dx);
    TEST_ASSERT_EQUAL_INT16(-2, d.pointer.dy);
    TEST_ASSERT_EQUAL_INT16(-1, d.pointer.vscroll);
    TEST_ASSERT_EQUAL_INT16(2, d.pointer.hscroll);
}

static void decodes_legacy_nine_byte_pointer_packet_with_zero_hscroll() {
    const uint8_t bytes[] = {0x01, 0x07, 0x01, 0x03, 0x00, 0xFE, 0xFF, 0xFF, 0xFF};

    Decoded d = decode(bytes, sizeof bytes);

    TEST_ASSERT_EQUAL(DecodeStatus::Pointer, d.status);
    TEST_ASSERT_EQUAL_INT16(-1, d.pointer.vscroll);
    TEST_ASSERT_EQUAL_INT16(0, d.pointer.hscroll);
}

static void decodes_negative_hscroll_and_ignores_trailing_bytes() {
    const uint8_t bytes[] = {0x01, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFD, 0xFF, 0xAA, 0xBB};

    Decoded d = decode(bytes, sizeof bytes);

    TEST_ASSERT_EQUAL(DecodeStatus::Pointer, d.status);
    TEST_ASSERT_EQUAL_INT16(-3, d.pointer.hscroll);
}

static void rejects_a_packet_shorter_than_nine_bytes() {
    const uint8_t bytes[] = {0x01, 0x07, 0x01, 0x03, 0x00, 0xFE, 0xFF, 0xFF};

    TEST_ASSERT_EQUAL(DecodeStatus::TooShort, decode(bytes, sizeof bytes).status);
    TEST_ASSERT_EQUAL(DecodeStatus::TooShort, decode(bytes, 0).status);
}

static void rejects_an_unknown_protocol_version() {
    const uint8_t bytes[] = {0x02, 0x07, 0x01, 0x03, 0x00, 0xFE, 0xFF, 0xFF, 0xFF};

    TEST_ASSERT_EQUAL(DecodeStatus::UnknownVersion, decode(bytes, sizeof bytes).status);
}

static void rejects_a_reserved_type() {
    const uint8_t bytes[] = {0x41, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

    TEST_ASSERT_EQUAL(DecodeStatus::ReservedType, decode(bytes, sizeof bytes).status);
}

static void decodes_the_protocol_example_keyboard_packet() {
    // PROTOCOL.md: Ctrl held with C (0x06), seq 4.
    const uint8_t bytes[] = {0x11, 0x04, 0x01, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00};

    Decoded d = decode(bytes, sizeof bytes);

    TEST_ASSERT_EQUAL(DecodeStatus::Keyboard, d.status);
    TEST_ASSERT_EQUAL_UINT8(4, d.keyboard.seq);
    TEST_ASSERT_EQUAL_UINT8(0x01, d.keyboard.modifiers);
    const uint8_t keys[6] = {0x06, 0, 0, 0, 0, 0};
    TEST_ASSERT_EQUAL_UINT8_ARRAY(keys, d.keyboard.keys, 6);
}

static void decodes_six_held_keys() {
    // F13..F18.
    const uint8_t bytes[] = {0x11, 0xFF, 0x00, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D};

    Decoded d = decode(bytes, sizeof bytes);

    TEST_ASSERT_EQUAL(DecodeStatus::Keyboard, d.status);
    const uint8_t keys[6] = {0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D};
    TEST_ASSERT_EQUAL_UINT8_ARRAY(keys, d.keyboard.keys, 6);
}

static void rejects_a_keyboard_packet_shorter_than_nine_bytes() {
    const uint8_t bytes[] = {0x11, 0x04, 0x01, 0x06, 0x00, 0x00, 0x00, 0x00};

    TEST_ASSERT_EQUAL(DecodeStatus::TooShort, decode(bytes, sizeof bytes).status);
}

// --- Advertising ------------------------------------------------------------

static void advertises_the_open_pairing_window() {
    // PROTOCOL.md: pairing window open is FF FF 01.
    uint8_t data[kAdvertDataSize];
    advertData(true, data);
    const uint8_t open[] = {0xFF, 0xFF, 0x01};
    TEST_ASSERT_EQUAL_UINT8_ARRAY(open, data, sizeof open);

    advertData(false, data);
    const uint8_t closed[] = {0xFF, 0xFF, 0x00};
    TEST_ASSERT_EQUAL_UINT8_ARRAY(closed, data, sizeof closed);
}

static void names_the_dongle_after_its_address() {
    const uint8_t address[6] = {0x02, 0x00, 0x00, 0x00, 0xA1, 0xB2};
    char name[kDongleNameSize];
    dongleName(address, name);
    TEST_ASSERT_EQUAL_STRING("Tocamatrol A1B2", name);
}

static void clean(const char* in, char out[kMaxNameLength + 1], size_t* len) {
    *len = cleanName(reinterpret_cast<const uint8_t*>(in), strlen(in), out);
}

static void cleans_a_written_name() {
    // PROTOCOL.md "Name characteristic": trim spaces, non-ASCII bytes become ?, 20 bytes at most.
    char name[kMaxNameLength + 1];
    size_t len;

    clean("  Desk Mac 3  ", name, &len);
    TEST_ASSERT_EQUAL_STRING("Desk Mac 3", name);
    TEST_ASSERT_EQUAL(10, len);

    clean("Caf\xC3\xA9", name, &len);  // "Café" in UTF-8
    TEST_ASSERT_EQUAL_STRING("Caf??", name);

    clean("ABCDEFGHIJKLMNOPQRS TUVWXYZ", name, &len);
    TEST_ASSERT_EQUAL_STRING("ABCDEFGHIJKLMNOPQRS", name);  // 20th byte was a space

    clean("   ", name, &len);
    TEST_ASSERT_EQUAL(0, len);  // empty: the default name
}

// --- Report planning -------------------------------------------------------

struct Plan {
    std::vector<MouseReport> reports;
    uint8_t heldAfter;
};

static Plan plan(uint8_t held, PointerPacket p) {
    Plan out;
    out.heldAfter = planReports(held, p, [&](const MouseReport& r) { out.reports.push_back(r); });
    return out;
}

static void assertReport(const MouseReport& r, uint8_t buttons, int x, int y, int wheel, int pan = 0) {
    TEST_ASSERT_EQUAL_UINT8(buttons, r.buttons);
    TEST_ASSERT_EQUAL_INT8(x, r.x);
    TEST_ASSERT_EQUAL_INT8(y, r.y);
    TEST_ASSERT_EQUAL_INT8(wheel, r.wheel);
    TEST_ASSERT_EQUAL_INT8(pan, r.pan);
}

static void small_move_with_steady_buttons_is_one_report() {
    Plan p = plan(0x01, PointerPacket{7, 0x01, 3, -2, -1, 1});

    TEST_ASSERT_EQUAL(1, p.reports.size());
    assertReport(p.reports[0], 0x01, 3, -2, -1, 1);
    TEST_ASSERT_EQUAL_UINT8(0x01, p.heldAfter);
}

static void large_move_is_split_into_steps_of_at_most_127() {
    Plan p = plan(0x00, PointerPacket{1, 0x00, 300, -130, 0, 0});

    TEST_ASSERT_EQUAL(3, p.reports.size());
    assertReport(p.reports[0], 0x00, 127, -127, 0);
    assertReport(p.reports[1], 0x00, 127, -3, 0);
    assertReport(p.reports[2], 0x00, 46, 0, 0);
}

static void scroll_goes_out_one_wheel_step_per_report() {
    Plan p = plan(0x00, PointerPacket{1, 0x00, 0, 0, -3, 0});

    TEST_ASSERT_EQUAL(3, p.reports.size());
    for (const MouseReport& r : p.reports) assertReport(r, 0x00, 0, 0, -1, 0);
}

static void horizontal_scroll_goes_out_one_pan_step_per_report() {
    Plan p = plan(0x00, PointerPacket{1, 0x00, 0, 0, 0, 3});

    TEST_ASSERT_EQUAL(3, p.reports.size());
    for (const MouseReport& r : p.reports) assertReport(r, 0x00, 0, 0, 0, 1);

    Plan left = plan(0x00, PointerPacket{2, 0x00, 4, 0, -1, -2});
    TEST_ASSERT_EQUAL(2, left.reports.size());
    assertReport(left.reports[0], 0x00, 4, 0, -1, -1);
    assertReport(left.reports[1], 0x00, 0, 0, 0, -1);
}

static void scroll_steps_ride_along_with_movement() {
    Plan p = plan(0x00, PointerPacket{1, 0x00, 5, 0, 2, 0});

    TEST_ASSERT_EQUAL(2, p.reports.size());
    assertReport(p.reports[0], 0x00, 5, 0, 1);
    assertReport(p.reports[1], 0x00, 0, 0, 1);
}

static void extreme_values_are_split_without_loss() {
    Plan p = plan(0x00, PointerPacket{1, 0x00, -32768, 32767, 0, 0});

    long sumX = 0, sumY = 0;
    for (const MouseReport& r : p.reports) {
        TEST_ASSERT_TRUE(r.x >= -127 && r.x <= 127);
        sumX += r.x;
        sumY += r.y;
    }
    TEST_ASSERT_EQUAL(-32768, sumX);
    TEST_ASSERT_EQUAL(32767, sumY);
    TEST_ASSERT_EQUAL(259, p.reports.size());  // ceil(32768 / 127)
}

static void press_goes_out_before_the_movement() {
    Plan p = plan(0x00, PointerPacket{1, 0x01, 10, 0, 0, 0});

    TEST_ASSERT_EQUAL(2, p.reports.size());
    assertReport(p.reports[0], 0x01, 0, 0, 0);
    assertReport(p.reports[1], 0x01, 10, 0, 0);
    TEST_ASSERT_EQUAL_UINT8(0x01, p.heldAfter);
}

static void release_goes_out_after_the_movement() {
    Plan p = plan(0x01, PointerPacket{1, 0x00, 10, 0, 0, 0});

    TEST_ASSERT_EQUAL(2, p.reports.size());
    assertReport(p.reports[0], 0x01, 10, 0, 0);
    assertReport(p.reports[1], 0x00, 0, 0, 0);
    TEST_ASSERT_EQUAL_UINT8(0x00, p.heldAfter);
}

static void button_change_without_movement_is_one_report() {
    Plan p = plan(0x00, PointerPacket{1, 0x02, 0, 0, 0, 0});

    TEST_ASSERT_EQUAL(1, p.reports.size());
    assertReport(p.reports[0], 0x02, 0, 0, 0);
}

static void swapping_buttons_presses_first_and_releases_last() {
    // Left was held; the packet holds right instead.
    Plan p = plan(0x01, PointerPacket{1, 0x02, 5, 0, 0, 0});

    TEST_ASSERT_EQUAL(3, p.reports.size());
    assertReport(p.reports[0], 0x03, 0, 0, 0);
    assertReport(p.reports[1], 0x03, 5, 0, 0);
    assertReport(p.reports[2], 0x02, 0, 0, 0);
    TEST_ASSERT_EQUAL_UINT8(0x02, p.heldAfter);
}

static void empty_packet_with_steady_buttons_sends_nothing() {
    Plan p = plan(0x01, PointerPacket{1, 0x01, 0, 0, 0, 0});

    TEST_ASSERT_EQUAL(0, p.reports.size());
}

// Several senders (PROTOCOL.md "Several senders").
static void merged_buttons_are_held_while_any_sender_holds_them() {
    InputMerger<3> m;
    PointerPacket a = m.pointer(0, PointerPacket{1, 0x01, 4, 0, 0, 0});
    TEST_ASSERT_EQUAL_UINT8(0x01, a.buttons);
    TEST_ASSERT_EQUAL_INT16(4, a.dx);
    // A second sender's scroll with no buttons must not release the first sender's left button.
    PointerPacket b = m.pointer(1, PointerPacket{9, 0x00, 0, 0, -3, 2});
    TEST_ASSERT_EQUAL_UINT8(0x01, b.buttons);
    TEST_ASSERT_EQUAL_INT16(-3, b.vscroll);
    TEST_ASSERT_EQUAL_INT16(2, b.hscroll);
    TEST_ASSERT_EQUAL_UINT8(9, b.seq);
    PointerPacket c = m.pointer(0, PointerPacket{2, 0x00, 0, 0, 0, 0});
    TEST_ASSERT_EQUAL_UINT8(0x00, c.buttons);
}

static void merged_keys_are_the_union_of_every_sender() {
    InputMerger<3> m;
    m.keyboard(0, KeyboardPacket{1, 0x01, {0x06, 0, 0, 0, 0, 0}});
    KeyboardPacket k = m.keyboard(1, KeyboardPacket{5, 0x02, {0x3A, 0x06, 0, 0, 0, 0}});
    TEST_ASSERT_EQUAL_UINT8(0x03, k.modifiers);
    TEST_ASSERT_EQUAL_UINT8(5, k.seq);
    TEST_ASSERT_EQUAL_UINT8(0x06, k.keys[0]);
    TEST_ASSERT_EQUAL_UINT8(0x3A, k.keys[1]);  // 0x06 held by both appears once
    TEST_ASSERT_EQUAL_UINT8(0, k.keys[2]);
    // Second sender lets go; first sender's Ctrl + C stay held.
    k = m.keyboard(1, KeyboardPacket{6, 0x00, {0, 0, 0, 0, 0, 0}});
    TEST_ASSERT_EQUAL_UINT8(0x01, k.modifiers);
    TEST_ASSERT_EQUAL_UINT8(0x06, k.keys[0]);
    TEST_ASSERT_EQUAL_UINT8(0, k.keys[1]);
}

static void merged_keys_stop_at_six() {
    InputMerger<2> m;
    m.keyboard(0, KeyboardPacket{1, 0, {4, 5, 6, 7, 8, 0}});
    KeyboardPacket k = m.keyboard(1, KeyboardPacket{1, 0, {9, 10, 11, 0, 0, 0}});
    const uint8_t want[6] = {4, 5, 6, 7, 8, 9};
    TEST_ASSERT_EQUAL_UINT8_ARRAY(want, k.keys, 6);
}

static void clearing_a_sender_releases_only_its_input() {
    InputMerger<3> m;
    m.pointer(0, PointerPacket{1, 0x01, 0, 0, 0, 0});
    m.pointer(1, PointerPacket{1, 0x02, 0, 0, 0, 0});
    m.keyboard(1, KeyboardPacket{1, 0x04, {0x2C, 0, 0, 0, 0, 0}});
    PointerPacket p;
    KeyboardPacket k;
    m.clear(1, p, k);
    TEST_ASSERT_EQUAL_UINT8(0x01, p.buttons);
    TEST_ASSERT_EQUAL_INT16(0, p.dx);
    TEST_ASSERT_EQUAL_INT16(0, p.vscroll);
    TEST_ASSERT_EQUAL_INT16(0, p.hscroll);
    TEST_ASSERT_EQUAL_UINT8(0x00, k.modifiers);
    TEST_ASSERT_EQUAL_UINT8(0, k.keys[0]);
    m.clearAll();
    TEST_ASSERT_EQUAL_UINT8(0, m.mergedButtons());
}

static void an_out_of_range_sender_changes_nothing() {
    InputMerger<2> m;
    m.pointer(0, PointerPacket{1, 0x01, 0, 0, 0, 0});
    PointerPacket p = m.pointer(7, PointerPacket{1, 0x04, 1, 0, 0, 0});
    TEST_ASSERT_EQUAL_UINT8(0x01, p.buttons);
}

static void decodes_a_status_packet() {
    const uint8_t bytes[] = {0x21, 87, 0x5C, 0x10};
    const Decoded d = decode(bytes, sizeof bytes);
    TEST_ASSERT_EQUAL(DecodeStatus::Status, d.status);
    TEST_ASSERT_EQUAL_UINT8(87, d.senderStatus.batteryPercent);
    TEST_ASSERT_EQUAL_UINT16(4188, d.senderStatus.millivolts);
}

static void a_status_packet_out_of_range_battery_is_unknown() {
    const uint8_t bytes[] = {0x21, 140, 0, 0};
    TEST_ASSERT_EQUAL_UINT8(kBatteryUnknown, decode(bytes, sizeof bytes).senderStatus.batteryPercent);
    const uint8_t shortBytes[] = {0x21, 50};
    TEST_ASSERT_EQUAL(DecodeStatus::TooShort, decode(shortBytes, sizeof shortBytes).status);
}

static void status_report_lists_each_slot() {
    SenderSlot slots[kStatusSlots];
    slots[0].state = SlotState::Connected;
    slots[2].state = SlotState::Reported;
    slots[2].batteryPercent = 64;
    slots[2].millivolts = 3850;
    uint8_t out[kPcReportSize];
    encodeStatusReport(slots, true, out);
    TEST_ASSERT_EQUAL_UINT8(kPcLayoutVersion, out[0]);
    TEST_ASSERT_EQUAL_UINT8(0x01, out[1]);
    TEST_ASSERT_EQUAL_UINT8(2, out[2]);
    TEST_ASSERT_EQUAL_UINT8(1, out[3]);
    TEST_ASSERT_EQUAL_UINT8(kBatteryUnknown, out[4]);
    TEST_ASSERT_EQUAL_UINT8(0, out[7]);
    TEST_ASSERT_EQUAL_UINT8(2, out[11]);
    TEST_ASSERT_EQUAL_UINT8(64, out[12]);
    TEST_ASSERT_EQUAL_UINT8(3850 & 0xFF, out[13]);
    TEST_ASSERT_EQUAL_UINT8(3850 >> 8, out[14]);
}

static void control_report_sets_scroll_hold_with_or_without_its_id() {
    Control c;
    uint8_t payload[kPcReportSize] = {kPcLayoutVersion, 0x01};
    TEST_ASSERT_TRUE(decodeControlReport(payload, sizeof payload, c));
    TEST_ASSERT_TRUE(c.scrollHold);
    TEST_ASSERT_FALSE(c.reverse);
    TEST_ASSERT_EQUAL_UINT8(0, c.senderMode);
    uint8_t withId[kPcReportSize + 1] = {kControlReportId, kPcLayoutVersion, 0x00};
    TEST_ASSERT_TRUE(decodeControlReport(withId, sizeof withId, c));
    TEST_ASSERT_FALSE(c.scrollHold);
    uint8_t wrongVersion[kPcReportSize] = {9, 0x01};
    c = Control{};
    TEST_ASSERT_FALSE(decodeControlReport(wrongVersion, sizeof wrongVersion, c));
    TEST_ASSERT_FALSE(c.scrollHold);
}

static void control_report_carries_sender_mode_and_reverse() {
    Control c;
    const uint8_t payload[kPcReportSize] = {kPcLayoutVersion, 0x03, 2};
    TEST_ASSERT_TRUE(decodeControlReport(payload, sizeof payload, c));
    TEST_ASSERT_TRUE(c.scrollHold);
    TEST_ASSERT_TRUE(c.reverse);
    TEST_ASSERT_EQUAL_UINT8(static_cast<uint8_t>(SenderMode::RotateRate), c.senderMode);
    uint8_t value[kControlValueSize];
    encodeControlValue(c.scrollHold, c.reverse, c.senderMode, value);
    TEST_ASSERT_EQUAL_UINT8(0x03, value[0]);
    TEST_ASSERT_EQUAL_UINT8(2, value[1]);
    encodeControlValue(false, true, 1, value);
    TEST_ASSERT_EQUAL_UINT8(0x02, value[0]);
    TEST_ASSERT_EQUAL_UINT8(1, value[1]);
}

static void scroll_hold_ends_without_a_refresh() {
    ScrollHold h;
    TEST_ASSERT_FALSE(h.active(0));
    h.set(true, 1000);
    TEST_ASSERT_TRUE(h.active(1000 + kScrollHoldTimeoutMs - 1));
    TEST_ASSERT_FALSE(h.active(1000 + kScrollHoldTimeoutMs));
    h.set(true, 2500);
    TEST_ASSERT_TRUE(h.active(3000));
    h.set(false, 3100);
    TEST_ASSERT_FALSE(h.active(3101));
}

static void decodes_a_scroll_rate_packet() {
    const uint8_t bytes[] = {0x31, 9, 0x40, 0xFF};  // -192/16 = -12 steps/s
    const Decoded d = decode(bytes, sizeof bytes);
    TEST_ASSERT_EQUAL(DecodeStatus::ScrollRate, d.status);
    TEST_ASSERT_EQUAL_UINT8(9, d.scrollRate.seq);
    TEST_ASSERT_EQUAL_INT16(-192, d.scrollRate.rateX16);
}

static void pacer_spaces_steps_evenly() {
    ScrollPacer<3> p;
    p.setRate(0, 200 * 16, 0);  // 200 steps/s: one every 5 ms
    int32_t total = 0;
    std::vector<uint32_t> at;
    for (uint32_t us = 1000; us <= 1000000; us += 1000) {
        if (us % 40000 == 0) p.setRate(0, 200 * 16, us);
        const int32_t s = p.advance(us);
        TEST_ASSERT_TRUE(s >= 0 && s <= 1);
        if (s) at.push_back(us);
        total += s;
    }
    TEST_ASSERT_INT_WITHIN(1, 200, total);
    for (size_t i = 1; i < at.size(); ++i) TEST_ASSERT_INT_WITHIN(1000, 5000, at[i] - at[i - 1]);
    TEST_ASSERT_EQUAL_UINT32(1000, at[0]);  // the first step comes at once from rest
}

static void pacer_edge_flicker_does_not_add_steps() {
    ScrollPacer<3> p;
    int32_t total = 0;
    for (uint32_t us = 0; us < 200000; us += 7000) {
        p.setRate(0, (us / 7000) % 2 ? 0 : 3 * 16, us);
        total += p.advance(us + 1000);
    }
    TEST_ASSERT_EQUAL(1, total);
    p.setRate(0, 0, 200000);
    p.advance(201000);
    p.setRate(0, 3 * 16, 600000);
    TEST_ASSERT_EQUAL(1, p.advance(601000));
}

static void pacer_slow_rate_and_direction() {
    ScrollPacer<3> p;
    p.setRate(1, -3 * 16, 0);  // 3 steps/s down
    int32_t total = 0;
    for (uint32_t us = 1000; us <= 1000000; us += 1000) {
        if (us % 40000 == 0) p.setRate(1, -3 * 16, us);
        total += p.advance(us);
    }
    TEST_ASSERT_INT_WITHIN(1, -3, total);
}

static void pacer_rate_expires_and_stops() {
    ScrollPacer<3> p;
    p.setRate(0, 100 * 16, 0);
    p.advance(50000);
    TEST_ASSERT_TRUE(p.active());
    TEST_ASSERT_EQUAL(0, p.advance(kRateExpiryUs + 1000));
    TEST_ASSERT_FALSE(p.active());
    p.setRate(0, 100 * 16, 200000);
    p.setRate(2, -50 * 16, 200000);
    p.stopAll();
    TEST_ASSERT_FALSE(p.active());
    p.setRate(0, 100 * 16, 300000);
    p.setRate(0, 0, 301000);
    TEST_ASSERT_FALSE(p.active());
}

int main() {
    UNITY_BEGIN();
    RUN_TEST(decodes_the_protocol_example_pointer_packet);
    RUN_TEST(decodes_legacy_nine_byte_pointer_packet_with_zero_hscroll);
    RUN_TEST(decodes_negative_hscroll_and_ignores_trailing_bytes);
    RUN_TEST(rejects_a_packet_shorter_than_nine_bytes);
    RUN_TEST(rejects_an_unknown_protocol_version);
    RUN_TEST(rejects_a_reserved_type);
    RUN_TEST(decodes_the_protocol_example_keyboard_packet);
    RUN_TEST(decodes_six_held_keys);
    RUN_TEST(rejects_a_keyboard_packet_shorter_than_nine_bytes);
    RUN_TEST(advertises_the_open_pairing_window);
    RUN_TEST(names_the_dongle_after_its_address);
    RUN_TEST(cleans_a_written_name);
    RUN_TEST(small_move_with_steady_buttons_is_one_report);
    RUN_TEST(large_move_is_split_into_steps_of_at_most_127);
    RUN_TEST(scroll_goes_out_one_wheel_step_per_report);
    RUN_TEST(horizontal_scroll_goes_out_one_pan_step_per_report);
    RUN_TEST(scroll_steps_ride_along_with_movement);
    RUN_TEST(extreme_values_are_split_without_loss);
    RUN_TEST(press_goes_out_before_the_movement);
    RUN_TEST(release_goes_out_after_the_movement);
    RUN_TEST(button_change_without_movement_is_one_report);
    RUN_TEST(swapping_buttons_presses_first_and_releases_last);
    RUN_TEST(empty_packet_with_steady_buttons_sends_nothing);
    RUN_TEST(merged_buttons_are_held_while_any_sender_holds_them);
    RUN_TEST(merged_keys_are_the_union_of_every_sender);
    RUN_TEST(merged_keys_stop_at_six);
    RUN_TEST(clearing_a_sender_releases_only_its_input);
    RUN_TEST(an_out_of_range_sender_changes_nothing);
    RUN_TEST(decodes_a_status_packet);
    RUN_TEST(a_status_packet_out_of_range_battery_is_unknown);
    RUN_TEST(status_report_lists_each_slot);
    RUN_TEST(control_report_sets_scroll_hold_with_or_without_its_id);
    RUN_TEST(control_report_carries_sender_mode_and_reverse);
    RUN_TEST(scroll_hold_ends_without_a_refresh);
    RUN_TEST(decodes_a_scroll_rate_packet);
    RUN_TEST(pacer_spaces_steps_evenly);
    RUN_TEST(pacer_slow_rate_and_direction);
    RUN_TEST(pacer_rate_expires_and_stops);
    RUN_TEST(pacer_edge_flicker_does_not_add_steps);
    return UNITY_END();
}
