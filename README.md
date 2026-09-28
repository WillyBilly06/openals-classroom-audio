# OpenALS classroom audio

An assistive-listening prototype built around an ESP32 audio transmitter, dedicated ESP32 receiver hardware, and a Flutter mobile interface for iOS and Android. The goal is a maintainable system that Cal Poly could evaluate as an alternative to AudioFetch; it has not been deployed as a campus service.

I developed the audio firmware and mobile application in the original `datalooper/openals` project. The project owner authorized publication of the ALS work. This repository is a clean source snapshot, with the original project history, credentials, generated builds, and copied vendor files omitted.

## What is implemented

| Area | Implementation |
| --- | --- |
| Transmitter | Captures PCM over I2S, encodes SBC, encrypts audio payloads, and broadcasts them over ESP-NOW to dedicated receivers. |
| Network audio | Provides an encrypted and authenticated UDP multicast path intended for mobile listeners. |
| Receiver | Handles encrypted audio packets and SBC playback on ESP32-based receiver hardware. |
| Mobile app | Flutter iOS and Android interface for room selection, status, and volume. Mobile discovery and live playback integration remain in progress. |

The ESP-NOW broadcast uses application-layer audio encryption; the broadcast peer itself is not configured for ESP-NOW link-layer encryption. The UDP path uses AES-CTR and CMAC. These are prototype transport implementations, not a completed security review.

## Repository layout

- `transmitter/`: ESP32 WROVER audio source, room control, Wi-Fi, and UDP streaming code.
- `receiver/p4_5inch/`: receiver audio component for the CrowPanel ESP32-P4 board.
- `receiver/c6_bridge/`: ESP32-C6 bridge firmware source.
- `mobile/`: Flutter application and Android/iOS project files.

The P4 receiver component depends on board support and vendor components from the original development environment. Those third-party trees are not bundled here. The receiver folder is therefore provided for code inspection and adaptation, not as a standalone build.

## Setup notes

1. Install the matching ESP-IDF and Flutter toolchains for the target hardware.
2. Copy `transmitter/main/source_raud_config.h.example` to `source_raud_config.h`. Replace all example keys with fresh random values and remove its `#error` line.
3. Copy each `ecast_secret.h.example` to `ecast_secret.h` for the receiver targets. Set the same fresh Broadcast_Code on the bridge and decoder, and remove the `#error` line. Never commit the real headers.
4. Configure Wi-Fi through the device interface. Change the example setup AP password in `transmitter/main/source_wifi.c` before flashing.
5. Build each firmware target with its board dependencies. Run `flutter pub get` in `mobile/` before building the Android or iOS app.

The supplied examples deliberately do not contain working keys or campus Wi-Fi credentials. The original private repository's keys should be rotated if they were used on deployed devices.

## Attribution and license

Original collaboration: `datalooper/openals`. ALS implementation and this source release: Ngoc Viet (William) Ho, with the project owner's permission. The code in this repository is released under the [MIT License](LICENSE); third-party dependencies retain their own licenses.
