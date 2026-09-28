"""Patch the network_adapter.bin version to force OTA update.
The factory C6 firmware is also 2.6.7, so we need to bump the version
in our firmware to trick the OTA into updating."""
import os
import shutil

BASE = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(BASE, "slave_firmware", "network_adapter.bin")
patched = os.path.join(BASE, "slave_firmware", "network_adapter_patched.bin")

# Read the binary
with open(src, "rb") as f:
    data = bytearray(f.read())

# Find the version string "2.6.7" in the binary
old_ver = b"2.6.7"
new_ver = b"2.6.8"

# Find ALL occurrences
indices = []
start = 0
while True:
    idx = data.find(old_ver, start)
    if idx == -1:
        break
    indices.append(idx)
    start = idx + 1

print(f"Found '{old_ver.decode()}' at {len(indices)} offset(s): {[hex(i) for i in indices]}")

# Patch the first occurrence (in app_desc)
if indices:
    data[indices[0]:indices[0]+len(old_ver)] = new_ver
    print(f"Patched version at offset {hex(indices[0])} from '2.6.7' to '2.6.8'")
else:
    print("ERROR: Could not find version string in binary!")
    exit(1)

# Write patched binary
with open(patched, "wb") as f:
    f.write(data)

print(f"Written patched firmware to: {patched}")
print(f"Size: {len(data)} bytes")

# Now rebuild the LittleFS storage image with the patched binary
import littlefs
BLOCK_SIZE = 4096
BLOCK_COUNT = 480  # 1,966,080 bytes

fs = littlefs.LittleFS(block_size=BLOCK_SIZE, block_count=BLOCK_COUNT)
with fs.open("network_adapter.bin", "wb") as f:
    f.write(bytes(data))

files = fs.listdir("/")
print(f"Files in LittleFS: {files}")

img = fs.context.buffer
out_path = os.path.join(BASE, "storage_with_fw.bin")
with open(out_path, "wb") as f:
    f.write(img)

print(f"Updated storage_with_fw.bin ({len(img)} bytes)")
