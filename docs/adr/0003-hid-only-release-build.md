# The release firmware exposes only HID interfaces

On a locked-down PC, any USB interface beyond plain HID (such as a USB serial port) can
trigger a driver prompt or a security alert. The release build exposes only a standard USB
HID mouse and keyboard. USB serial logging exists only when the debug build flag is set.

## Amendment

An optional vendor-defined HID feature collection (`TOCA_PC_CHANNEL`) exists in the dongle
source for custom integrations, compiled **out** by default (`TOCA_PC_CHANNEL=0`) so all
public release binaries expose only a standard USB mouse and keyboard.

## Consequences

Re-flashing a release dongle requires holding the board's BOOT button while plugging it in
(or using the dedicated UART port on dual-USB DevKitC-1 boards), because no USB CDC serial
port is exposed to auto-reset into the bootloader.
