# ESP-IDF and project setup

This repository includes the official [Espressif ESP-IDF](https://github.com/espressif/esp-idf) source as a Git submodule at tag `v5.5.1` (`fcae32885b0296b32044cb99ecbdc50d98dddb83`). The original ALS branch used locally installed ESP-IDF; the thousands of `build/esp-idf/` paths in that branch are compiler output, not SDK source files.

## Get the SDK

```powershell
git clone --recurse-submodules https://github.com/WillyBilly06/openals-classroom-audio.git
cd openals-classroom-audio
.\third_party\esp-idf\install.ps1 esp32,esp32c6,esp32p4
.\third_party\esp-idf\export.ps1
```

On Linux or macOS, use the SDK's `install.sh` and `export.sh` instead. The C6 SDIO OTA project in the original tree specifies ESP-IDF v5.5.1. The CrowPanel P4 demo README states v5.4 or later; both P4 display variants compiled with the pinned v5.5.1 SDK for this release.

On Windows, clone into a path without spaces. The pinned `espressif/esp_ipa` dependency splits an absolute camera JSON path at spaces during image generation.

## Before firmware builds

- Create `transmitter/main/source_raud_config.h` from its `.example` file and replace all example keys with random values.
- Create `ecast_secret.h` from its `.example` file in each receiver target that uses it. Use the same Broadcast_Code on the C6 bridge and P4 decoder. The real key headers are ignored by Git.
- Configure Wi-Fi for your environment and change the example setup AP password in `transmitter/main/source_wifi.c`.
- The P4 five-inch and seven-inch projects include their display app, board support, and ESP-Hosted host source. ESP-IDF downloads the remaining managed dependencies using each project's `main/idf_component.yml`. It generates a local `dependencies.lock` with machine-specific paths during configuration.
- The original demo's third-party MP3 samples are replaced by a placeholder SPIFFS directory; the ALS receiver does not use those samples. Prebuilt device firmware images and unused codec implementations are omitted.

## Projects

`transmitter/` is an ESP-IDF project for ESP32 WROVER. `receiver/c6_bridge/`, `receiver/c6_sdio_ota/`, and `receiver/p4_c6_flasher/` are separate ESP-IDF projects for their documented hardware targets. `receiver/p4_5inch/` and `receiver/p4_7inch/` are separate ESP32-P4 display projects. Each project has its own `CMakeLists.txt` and `sdkconfig.defaults`.

Build the display variants independently from an ESP-IDF shell:

```powershell
cd receiver/p4_5inch
idf.py build
cd ../p4_7inch
idf.py build
```

The Flutter application is in `mobile/`:

```powershell
cd mobile
flutter pub get
flutter analyze
```

The Android and iOS interfaces are present. Live network discovery and audio playback in the mobile app are still in progress. Both P4 display firmware variants were compiled with ESP-IDF v5.5.1 from a Windows checkout without spaces. Flashing to hardware and live audio behavior were not revalidated as part of this public source release.

## Third-party components

ESP-IDF is an external Espressif project and retains its own licenses. The `receiver/c6_sdio_ota/` subproject and the included P4 display demo, board support, and ESP-Hosted components retain their upstream Apache 2.0 license notices. Managed dependencies downloaded during the build retain their respective licenses; they are not covered by the root MIT license.
