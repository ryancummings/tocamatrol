# The dongle accepts input only from bonded phones

The dongle can type keystrokes and move the pointer on any PC it is plugged into, so an
unauthenticated phone within radio range could inject input. The dongle requires an
encrypted, bonded link (LE Secure Connections) for its input characteristic, and accepts a
new bond only during a short pairing window after power-up or a button press. Outside that
window it disconnects phones it has not bonded with.

## Considered Options

- **Passkey entry**: stronger against a nearby attacker during pairing, but boards without a
  screen (such as Seeed XIAO ESP32-S3) would require a fixed PIN. Rejected in favor of the
  time-limited physical pairing window.
- **Open link**: fastest to build, but leaves an unauthenticated keystroke path into the PC.
