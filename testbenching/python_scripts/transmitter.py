import serial

ser = serial.Serial('/dev/ttyUSB0', 115200)

length = 52
ser.write(length.to_bytes(4, 'little'))

# send program instructions (little-endian)
instructions = [
    0x00000093,  # addi x1, x0, 0
    0x00100113,  # addi x2, x0, 1
]

for instr in instructions:
    ser.write(instr.to_bytes(4, 'little'))

print("Program loaded!")