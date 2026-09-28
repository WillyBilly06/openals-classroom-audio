import littlefs
import os

# Storage partition is 0x1E0000 = 1,966,080 bytes
# block_size=4096, block_count=480 => 1,966,080
BLOCK_SIZE = 4096
BLOCK_COUNT = 480

fs = littlefs.LittleFS(block_size=BLOCK_SIZE, block_count=BLOCK_COUNT)

# Read the C6 firmware
fw_path = os.path.join(os.path.dirname(__file__), 'slave_firmware', 'network_adapter.bin')
with open(fw_path, 'rb') as f:
    fw_data = f.read()

print(f"Firmware size: {len(fw_data)} bytes")

# Write firmware into LittleFS as a file
with fs.open('network_adapter.bin', 'wb') as f:
    f.write(fw_data)

# Verify
files = fs.listdir('/')
print(f"Files in LittleFS: {files}")

# Write the filesystem image
img = fs.context.buffer
out_path = os.path.join(os.path.dirname(__file__), 'storage_with_fw.bin')
with open(out_path, 'wb') as f:
    f.write(img)

print(f"Created {out_path}")
print(f"Image size: {len(img)} bytes (expected {BLOCK_SIZE * BLOCK_COUNT})")
