# OpenALS classroom audio

An assistive-listening prototype built around an ESP32 audio transmitter, dedicated ESP32 receiver hardware, and a Flutter mobile interface for iOS and Android. The goal is a maintainable system that Cal Poly could evaluate as an alternative to AudioFetch; it has not been deployed as a campus service.

I developed the audio firmware and mobile application in the original `datalooper/openals` project. The project owner authorized publication of the ALS work. This repository is a source snapshot, with the original project history, credentials, and generated builds omitted. The ESP32-P4 receiver folders include the modified upstream display demo components they require; those components retain their own license notices.

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
- [5-inch receiver](receiver/p4_5inch/) and [7-inch receiver](receiver/p4_7inch/): separate ESP32-P4 projects with ALS receiver audio, display settings apps and assets, modified board support, ESP-Hosted host code, and OTA components.
- `receiver/c6_bridge/`: ESP32-C6 bridge firmware source.
- `receiver/c6_sdio_ota/` and `receiver/p4_c6_flasher/`: C6 OTA and P4/C6 flasher project source.
- `tools/`: board build/flash scripts and ESP32-P4/C6 firmware patch tools.
- `mobile/`: Flutter application and platform project files.
- `third_party/esp-idf/`: Git submodule pointing to the official Espressif ESP-IDF v5.5.1 source.

The original branch tracked about 64,000 files, largely generated `build/` output and copied dependencies. The original branch did not contain ESP-IDF SDK source; its `build/esp-idf/` paths were compiled output. This repository links the official SDK as a submodule and includes the display source and local components used by both P4 projects. Dependency-manager packages are resolved from the checked-in manifests; generated output and device firmware binaries are omitted.

See [ESP-IDF setup and dependency notes](docs/BUILDING.md) before attempting a firmware build.

## Setup notes

1. Clone with submodules and set up the included ESP-IDF toolchain. ESP-IDF v5.5.1 is pinned for the C6 OTA work; the P4 board demo originally documents v5.4 or later. See [BUILDING.md](docs/BUILDING.md).
2. Copy `transmitter/main/source_raud_config.h.example` to `source_raud_config.h`. Replace all example keys with fresh random values and remove its `#error` line.
3. Copy each `ecast_secret.h.example` to `ecast_secret.h` for the receiver targets. Set the same fresh Broadcast_Code on the bridge and decoder, and remove the `#error` line. Never commit the real headers.
4. Configure Wi-Fi through the device interface. Change the example setup AP password in `transmitter/main/source_wifi.c` before flashing.
5. Build each firmware target after ESP-IDF resolves its managed dependencies. Run `flutter pub get` in `mobile/` before building the Android or iOS app.

The supplied examples deliberately do not contain working keys or campus Wi-Fi credentials. The original private repository's keys should be rotated if they were used on deployed devices.

## Attribution and license

Original collaboration: `datalooper/openals`. ALS implementation and this source release: Ngoc Viet (William) Ho, with the project owner's permission. Original ALS code is released under the [MIT License](LICENSE). The included Espressif display demo, board support, and ESP-Hosted components retain their Apache 2.0 licenses and notices. Managed dependencies and ESP-IDF retain their own licenses. The interface is a student prototype and is not an official Cal Poly service.
