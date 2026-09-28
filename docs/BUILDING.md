# ESP-IDF and project setup

This repository includes the official [Espressif ESP-IDF](https://github.com/espressif/esp-idf) source as a Git submodule at tag `v5.5.1` (`fcae32885b0296b32044cb99ecbdc50d98dddb83`). The original ALS branch used locally installed ESP-IDF; the thousands of `build/esp-idf/` paths in that branch are compiler output, not SDK source files.

## Get the SDK

```powershell
git clone --recurse-submodules https://github.com/WillyBilly06/openals-classroom-audio.git
cd openals-classroom-audio
.\third_party\esp-idf\install.ps1 esp32,esp32c6,esp32p4
.\third_party\esp-idf\export.ps1
```

On Linux or macOS, use the SDK's `install.sh` and `export.sh` instead. The C6 SDIO OTA project in the original tree specifies ESP-IDF v5.5.1. The CrowPanel P4 demo README states v5.4 or later; it has not been revalidated with the pinned SDK in this public snapshot.

## Before firmware builds

- Create `transmitter/main/source_raud_config.h` from its `.example` file and replace all example keys with random values.
- Create `ecast_secret.h` from its `.example` file in each receiver target that uses it. Use the same Broadcast_Code on the C6 bridge and P4 decoder. The real key headers are ignored by Git.
- Configure Wi-Fi for your environment and change the example setup AP password in `transmitter/main/source_wifi.c`.
- Obtain the CrowPanel board support and demo dependencies that the original P4 application used. The public tree includes the ALS board integration and receiver audio component but does not bundle copied vendor demo apps, proprietary codec sources, or prebuilt device firmware images. The P4 application will not build until those dependencies are restored or its demo UI is replaced.

## Projects

`transmitter/` is an ESP-IDF project for ESP32 WROVER. `receiver/c6_bridge/`, `receiver/c6_sdio_ota/`, and `receiver/p4_c6_flasher/` are separate ESP-IDF projects for their documented hardware targets. `receiver/p4_5inch/` and `receiver/p4_7inch/` contain the ESP32-P4 board integrations. Each project has its own `CMakeLists.txt` and `sdkconfig.defaults`.

The Flutter application is in `mobile/`:

```powershell
cd mobile
flutter pub get
flutter analyze
```

The Android and iOS interfaces are present. Live network discovery and audio playback in the mobile app are still in progress. Hardware firmware builds and live audio behavior were not revalidated as part of this public source release.

## Third-party components

ESP-IDF is an external Espressif project and retains its own licenses. The `receiver/c6_sdio_ota/` subproject carries its upstream Apache 2.0 license. Board support, hosted networking, codec libraries, and demo applications from the original private tree must be obtained and used under their respective terms; they are not covered by the root MIT license.
