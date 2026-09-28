"""Flash storage_with_fw.bin and OTA host to ESP32-P4, then monitor OTA output."""
import subprocess
import sys
import os

ESPTOOL = [sys.executable, "-m", "esptool"]
PORT = "COM13"
BAUD = "460800"
BASE = os.path.dirname(os.path.abspath(__file__))

def run(args, desc):
    print(f"\n{'='*60}")
    print(f"  {desc}")
    print(f"{'='*60}")
    result = subprocess.run(args, capture_output=False, text=True)
    if result.returncode != 0:
        print(f"WARNING: {desc} returned code {result.returncode}")
    return result.returncode

# Step 1: Flash storage with firmware
print("Step 1: Flashing storage_with_fw.bin to 0x410000...")
run(ESPTOOL + [
    "--chip", "esp32p4", "-p", PORT, "-b", BAUD,
    "--before", "default_reset", "--after", "no_reset",
    "write_flash", "--force", "--no-compress",
    "0x410000", os.path.join(BASE, "storage_with_fw.bin")
], "Flash storage partition")

# Step 2: Flash OTA host
print("\nStep 2: Flashing OTA host firmware...")
run(ESPTOOL + [
    "--chip", "esp32p4", "-p", PORT, "-b", BAUD,
    "--before", "no_reset", "--after", "hard_reset",
    "write_flash", "--force", "--no-compress",
    "0x2000", os.path.join(BASE, "binaries", "bootloader.bin"),
    "0x8000", os.path.join(BASE, "binaries", "partition-table.bin"),
    "0xd000", os.path.join(BASE, "binaries", "ota_data_initial.bin"),
    "0x10000", os.path.join(BASE, "modified_ota_host", "host_performs_slave_ota.bin"),
], "Flash OTA host")

print("\n" + "="*60)
print("  Flash complete! Board will reset and run OTA.")
print("  The OTA host will update the C6 firmware over SDIO.")
print("="*60)
