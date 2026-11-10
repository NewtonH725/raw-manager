#!/usr/bin/env python3
"""
execution/generate_test_rafs.py
Genera deterministicamente file binari sintetici .RAF Fujifilm (validi, corrotti, troncati)
in .tmp/synthetic_rafs/ per i test unitari e benchmark.
"""

import os
import struct
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
TARGET_DIR = BASE_DIR / ".tmp" / "synthetic_rafs"

# Magic header Fujifilm esatto a 16 byte
RAF_MAGIC = b"FUJIFILMCCD-RAW "

def build_minimal_jpeg(index: int) -> bytes:
    """Costruisce un buffer JPEG valido con marcatore EXIF APP1 e marcatore immagine."""
    # EXIF APP1 header con Make=FUJIFILM, Model=X-T5, ISO=index*100, FNumber=2.8
    # Usiamo un JPEG minimo valido con SOI (0xFF 0xD8) ed EOI (0xFF 0xD9)
    # Header JFIF/EXIF
    exif_payload = (
        b"Exif\x00\x00"
        b"MM\x00*\x00\x00\x00\x08" # TIFF header Big-Endian
        b"\x00\x02" # 2 entries
        # Tag 0x010F: Make = "FUJIFILM\0"
        b"\x01\x0f\x00\x02\x00\x00\x00\x09\x00\x00\x00\x26"
        # Tag 0x0110: Model = "X-T5\0"
        b"\x01\x10\x00\x02\x00\x00\x00\x05\x00\x00\x00\x2f"
        b"\x00\x00\x00\x00" # Next IFD offset
        b"FUJIFILM\x00" # offset 0x26
        b"X-T5\x00"     # offset 0x2f
    )
    app1_marker = b"\xff\xe1" + struct.pack(">H", len(exif_payload) + 2) + exif_payload

    # Minimal 1x1 image payload
    dqt = (
        b"\xff\xdb\x00\x43\x00"
        + bytes([index % 250 + 1] * 64)
    )
    sof = b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
    dht = (
        b"\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00"
        b"\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b"
    )
    sos = b"\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00\x7f\x00"

    jpeg_bytes = b"\xff\xd8" + app1_marker + dqt + sof + dht + sos + b"\xff\xd9"
    return jpeg_bytes

def create_valid_raf(file_path: Path, index: int, extra_raw_kb: int = 50):
    """Crea un file .RAF valido che rispetta la specifica Fujifilm a 0x54 e 0x58."""
    jpeg = build_minimal_jpeg(index)
    
    # Header di 92 byte:
    # 0x00-0x0F: 16 byte "FUJIFILMCCD-RAW "
    # 0x10-0x53: padding (68 byte)
    # 0x54-0x57: jpegOffset (Uint32 Big-Endian)
    # 0x58-0x5B: jpegLength (Uint32 Big-Endian)
    header = bytearray(92)
    header[0:16] = RAF_MAGIC
    header[16:84] = b"\x00" * 68
    
    jpeg_offset = 128 # Iniziamo il JPEG a offset 128 (lasciando 36 byte di padding header)
    jpeg_length = len(jpeg)
    
    struct.pack_into(">I", header, 0x54, jpeg_offset)
    struct.pack_into(">I", header, 0x58, jpeg_length)
    
    with open(file_path, "wb") as f:
        f.write(header)
        # Scrivi padding fino a jpeg_offset
        f.write(b"\x00" * (jpeg_offset - len(header)))
        # Scrivi stream JPEG
        f.write(jpeg)
        # Scrivi finto blocco dati RAW
        f.write(os.urandom(extra_raw_kb * 1024))
        
    print(f"[OK] Creato RAF valido: {file_path.name} (Offset: {jpeg_offset}, Len: {jpeg_length})")

def create_corrupted_magic_raf(file_path: Path):
    """Crea un file .RAF con magic bytes errati."""
    data = bytearray(1024)
    data[0:16] = b"CORRUPTED_MAGIC!"
    struct.pack_into(">I", data, 0x54, 128)
    struct.pack_into(">I", data, 0x58, 256)
    with open(file_path, "wb") as f:
        f.write(data)
    print(f"[OK] Creato RAF con magic errata: {file_path.name}")

def create_truncated_raf(file_path: Path):
    """Crea un file .RAF in cui jpegLength supera la dimensione reale del file."""
    header = bytearray(92)
    header[0:16] = RAF_MAGIC
    # Dichiariamo jpegOffset = 100 e jpegLength = 5000000 (5 MB) ma il file sarà di soli 200 byte
    struct.pack_into(">I", header, 0x54, 100)
    struct.pack_into(">I", header, 0x58, 5_000_000)
    with open(file_path, "wb") as f:
        f.write(header)
        f.write(b"\xff\xd8" + b"\x00" * 106) # Totale 200 byte, JPEG incompleto
    print(f"[OK] Creato RAF troncato: {file_path.name}")

def create_valid_dng(file_path: Path, index: int):
    """Crea un file .DNG conforme allo standard TIFF con anteprima JPEG incorporata."""
    jpeg = build_minimal_jpeg(index)
    
    # Costruisci IFD0 TIFF Little-Endian (II)
    # Header: 8 byte
    # IFD: 2 byte (count) + 4 entries * 12 byte + 4 byte (next IFD) = 54 byte
    # JPEG Offset = 8 + 54 = 62 (allineato a 64 byte)
    jpeg_offset = 64
    jpeg_length = len(jpeg)
    
    data = bytearray(jpeg_offset + jpeg_length)
    # Header: II, 42, offset IFD = 8
    struct.pack_into("<2sHI", data, 0, b"II", 42, 8)
    
    # IFD0 con 3 entries
    num_entries = 3
    struct.pack_into("<H", data, 8, num_entries)
    
    # Entry 1: 0x00FE (NewSubfileType)
    struct.pack_into("<HHII", data, 10, 0x00FE, 4, 1, 0)
    # Entry 2: 0x0201 (JPEGInterchangeFormat)
    struct.pack_into("<HHII", data, 22, 0x0201, 4, 1, jpeg_offset)
    # Entry 3: 0x0202 (JPEGInterchangeFormatLength)
    struct.pack_into("<HHII", data, 34, 0x0202, 4, 1, jpeg_length)
    # Next IFD: 0
    struct.pack_into("<I", data, 46, 0)
    
    # Payload JPEG
    data[jpeg_offset:jpeg_offset + jpeg_length] = jpeg
    
    with open(file_path, "wb") as f:
        f.write(data)
    print(f"[OK] Creato DNG valido: {file_path.name} (Offset: {jpeg_offset}, Len: {jpeg_length})")

def main():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    print(f"=== Generazione Dataset RAF Sintetico in {TARGET_DIR} ===")
    
    # 5 file validi .RAF
    for i in range(1, 6):
        create_valid_raf(TARGET_DIR / f"DSCF000{i}.RAF", index=i)
        
    # 2 file validi .DNG / .ARW
    create_valid_dng(TARGET_DIR / "SAMPLE_01.DNG", index=10)
    create_valid_dng(TARGET_DIR / "SAMPLE_02.ARW", index=20)

    # 1 file con magic errata
    create_corrupted_magic_raf(TARGET_DIR / "DSCF_CORRUPTED_MAGIC.RAF")
    
    # 1 file troncato
    create_truncated_raf(TARGET_DIR / "DSCF_TRUNCATED.RAF")
    
    print("=== Generazione completata con successo ===")

if __name__ == "__main__":
    main()
