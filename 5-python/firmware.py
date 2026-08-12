#!/usr/bin/env python3

import sys
import time
import serial
import struct
from pathlib import Path


def extract_text_section(elf_path):
    """
    Extract .text section from ELF binary.
    Returns bytes of the program code.
    """
    # Simple ELF parser: look for .text section
    # For a minimal implementation, read the entire ELF and extract based on headers
    
    with open(elf_path, 'rb') as f:
        data = f.read()
    
    # ELF header: check magic
    if data[0:4] != b'\x7fELF':
        raise ValueError(f"{elf_path} is not an ELF file")
    
    # For now, assume the .text section starts at a known offset
    # This is a simplification; real parsers use the ELF section headers
    # Typical RISC-V ELF: text starts at offset 0x1000 or similar
    
    # Extract everything after the ELF header as program bytes
    # (Assumes linker put code immediately after headers)
    
    # A more robust approach: parse the ELF properly
    # For a quick bootloader, assume layout: [ELF header (0x40 bytes)] [program code]
    
    # Read program entry point and size from ELF header
    e_entry = struct.unpack('<I', data[0x18:0x1c])[0]  # Entry point (little-endian, 32-bit)
    
    print(f"[*] ELF entry point: 0x{e_entry:08x}")
    
    # For simplicity: scan for first non-zero section and assume it's .text
    # Better: use a proper ELF parser like pyelftools
    # For now, just send everything after headers
    
    # Minimal hack: look for first code pattern (likely RISC-V instruction)
    # and extract from there to end of file
    # 
    # For production, use: pip install pyelftools
    # 
    # But for immediate testing, assume:
    # - Binary is already stripped to just .text bytes
    # - Or use readelf -x .text to get hex dump and convert
    
    # Read raw code section (assume it starts after minimal headers)
    text_start = 0x1000  # Typical .text offset in simple RISC-V ELF
    if len(data) > text_start:
        text_data = data[text_start:]
    else:
        # Assume entire file after ELF header
        text_data = data[0x40:]
    
    # Trim trailing zeros
    while text_data and text_data[-1] == 0:
        text_data = text_data[:-1]
    
    print(f"[*] Extracted {len(text_data)} bytes of code")
    return text_data


def load_program(elf_path, port='/dev/ttyUSB0', baudrate=115200, timeout=5):
    """
    Load ELF binary into SoC via UART bootloader.
    
    Args:
        elf_path: path to RISC-V ELF binary
        port: serial port (e.g., /dev/ttyUSB0 on Linux/Mac, COM3 on Windows)
        baudrate: UART baud rate (default 115200)
        timeout: serial read timeout in seconds
    """
    
    # Extract program bytes
    print(f"[*] Reading ELF: {elf_path}")
    program = extract_text_section(elf_path)
    
    if len(program) == 0:
        print("[-] No code found in ELF")
        return False
    
    if len(program) > 0x4000:  # 16 kB imem max
        print(f"[-] Program too large: {len(program)} bytes (max 0x4000)")
        return False
    
    # Connect to serial port
    print(f"[*] Connecting to {port} @ {baudrate} baud...")
    try:
        ser = serial.Serial(port, baudrate, timeout=timeout)
        time.sleep(0.5) 
    except Exception as e:
        print(f"[-] Failed to open {port}: {e}")
        return False
    
    try:
        length = len(program)
        len_high = (length >> 8) & 0xFF
        len_low = length & 0xFF
        
        print(f"[*] Sending program length: {length} bytes (0x{len_high:02x}{len_low:02x})")
        ser.write(bytes([len_high, len_low]))
        time.sleep(0.01)
        
        # Send program bytes
        print(f"[*] Sending program bytes...")
        ser.write(program)
        
        # Wait for bootloader to finish (signals cpu_enable)
        # In reality, you could add a ACK byte or just wait for timeout
        print(f"[*] Boot sequence complete!")
        print(f"[*] CPU should be running from 0x0000_0000")
        
        return True
        
    except Exception as e:
        print(f"[-] Error during transmission: {e}")
        return False
    
    finally:
        ser.close()
        print("[*] Serial port closed")


def usage():
    print("Usage: python3 bootload.py <elf_file> [serial_port] [baudrate]")
    print("  elf_file: path to RISC-V ELF binary")
    print("  serial_port: serial device (default: /dev/ttyUSB0)")
    print("  baudrate: UART speed (default: 115200)")
    print()
    print("Examples:")
    print("  python3 bootload.py program.elf")
    print("  python3 bootload.py program.elf /dev/ttyUSB0 115200")
    print("  python3 bootload.py program.elf COM3 115200  (Windows)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)
    
    elf_file = sys.argv[1]
    port = sys.argv[2] if len(sys.argv) > 2 else "/dev/ttyUSB0"
    baudrate = int(sys.argv[3]) if len(sys.argv) > 3 else 115200
    
    if not Path(elf_file).exists():
        print(f"[-] File not found: {elf_file}")
        sys.exit(1)
    
    success = load_program(elf_file, port=port, baudrate=baudrate)
    sys.exit(0 if success else 1)