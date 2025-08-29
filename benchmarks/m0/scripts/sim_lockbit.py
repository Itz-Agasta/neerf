#!/usr/bin/env python3
"""
Ethical LockBit simulator for M0 benchmark
Produces realistic file encryption patterns for NERRF testing
"""
import os
import time
import secrets
import pathlib
import json
import hashlib
from datetime import datetime

TARGET = "/app/uploads"
EXT = ".lockbit3"
README = "README_LOCKBIT.txt"
RATE_LIMIT = 1.0  # MB/sec to simulate realistic encryption speed

def log_event(event_type, path, size=0):
    """Log events for tracing"""
    timestamp = datetime.utcnow().isoformat()
    event = {
        "timestamp": timestamp,
        "event": event_type,
        "path": str(path),
        "size": size,
        "pid": os.getpid()
    }
    print(f"TRACE: {json.dumps(event)}")

def seed_files(n=20):
    """Create initial victim files (10-20 MB total)"""
    pathlib.Path(TARGET).mkdir(parents=True, exist_ok=True)
    log_event("seed_start", TARGET)
    
    total_size = 0
    for i in range(n):
        file_size = secrets.randbelow(512*1024) + 256*1024  # 256KB - 768KB per file
        file_path = pathlib.Path(TARGET) / f"document_{i:03d}.dat"
        
        # Write file in chunks to simulate real file creation
        with open(file_path, 'wb') as f:
            written = 0
            while written < file_size:
                chunk_size = min(8192, file_size - written)
                chunk = secrets.token_bytes(chunk_size)
                f.write(chunk)
                written += chunk_size
                
        total_size += file_size
        log_event("file_created", file_path, file_size)
        
        # Small delay between file creation
        time.sleep(0.1)
    
    print(f"[+] Seeded {n} files, total size: {total_size/1024/1024:.2f} MB")
    log_event("seed_complete", TARGET, total_size)

def encrypt_files():
    """Simulate LockBit-style encryption with realistic timing"""
    files = list(pathlib.Path(TARGET).glob("*.dat"))
    if not files:
        print("[-] No .dat files found to encrypt!")
        return
    
    log_event("encryption_start", TARGET)
    ransom_note = """
╔══════════════════════════════════════════════════════════════════╗
║                    *** LOCKBIT 3.0 SIMULATION ***                ║
║                                                                  ║
║  This is an ETHICAL SIMULATION for NERRF testing purposes only  ║
║                                                                  ║
║  Your files have been encrypted for research validation.         ║
║  To restore: mv *.lockbit3 files back to *.dat                  ║
║                                                                  ║
║  NERRF Recovery Target: MTTR < 60 minutes, Loss < 128 MB        ║
╚══════════════════════════════════════════════════════════════════╝
"""
    
    encrypted_count = 0
    total_encrypted_size = 0
    
    for file_path in files:
        if not file_path.exists():
            continue
            
        original_size = file_path.stat().st_size
        log_event("file_encrypt_start", file_path, original_size)
        
        # Read original file
        with open(file_path, 'rb') as f:
            original_data = f.read()
        
        # Simulate encryption by XOR with pseudo-random key
        key = hashlib.sha256(f"lockbit_key_{file_path.name}".encode()).digest()
        encrypted_data = bytearray()
        
        # Process in chunks with rate limiting
        chunk_size = 64 * 1024  # 64KB chunks
        processed = 0
        start_time = time.time()
        
        for i in range(0, len(original_data), chunk_size):
            chunk = original_data[i:i+chunk_size]
            # Simple XOR encryption
            encrypted_chunk = bytes(a ^ key[j % len(key)] for j, a in enumerate(chunk))
            encrypted_data.extend(encrypted_chunk)
            
            processed += len(chunk)
            
            # Rate limiting to simulate 1 MB/sec
            elapsed = time.time() - start_time
            expected_time = processed / (RATE_LIMIT * 1024 * 1024)
            if elapsed < expected_time:
                sleep_time = expected_time - elapsed
                time.sleep(sleep_time)
        
        # Write encrypted file
        encrypted_path = file_path.with_suffix(EXT)
        with open(encrypted_path, 'wb') as f:
            f.write(encrypted_data)
        
        # Remove original file (simulation of real ransomware behavior)
        file_path.unlink()
        
        encrypted_count += 1
        total_encrypted_size += original_size
        
        log_event("file_encrypt_complete", encrypted_path, original_size)
        print(f"[+] Encrypted: {file_path.name} -> {encrypted_path.name} ({original_size/1024:.1f} KB)")
    
    # Write ransom note
    ransom_path = pathlib.Path(TARGET) / README
    with open(ransom_path, 'w') as f:
        f.write(ransom_note)
    
    log_event("ransom_note_created", ransom_path, len(ransom_note))
    log_event("encryption_complete", TARGET, total_encrypted_size)
    
    print(f"[+] Encryption complete: {encrypted_count} files, {total_encrypted_size/1024/1024:.2f} MB")
    print(f"[+] Ransom note: {ransom_path}")

def simulate_lateral_movement():
    """Simulate basic reconnaissance and lateral movement patterns"""
    log_event("lateral_movement_start", "/")
    
    # Simulate process enumeration
    try:
        os.system("ps aux > /tmp/processes.txt 2>/dev/null || true")
        log_event("process_enum", "/tmp/processes.txt")
    except:
        pass
    
    # Simulate network discovery
    try:
        os.system("netstat -an > /tmp/network.txt 2>/dev/null || true")
        log_event("network_enum", "/tmp/network.txt")
    except:
        pass
    
    log_event("lateral_movement_complete", "/")

def main():
    """Main LockBit simulation flow"""
    print("=" * 60)
    print("NERRF M0 Ethical LockBit Simulation")
    print("=" * 60)
    
    start_time = datetime.utcnow()
    log_event("simulation_start", TARGET)
    
    try:
        # Phase 1: Initial access (already simulated by pod deployment)
        print("[Phase 1] Initial access - SIMULATED")
        time.sleep(1)
        
        # Phase 2: Discovery and reconnaissance
        print("[Phase 2] Discovery and reconnaissance")
        simulate_lateral_movement()
        time.sleep(2)
        
        # Phase 3: File seeding (victim data)
        print("[Phase 3] Creating victim files")
        seed_files(25)  # Create ~15-20 MB of data
        time.sleep(1)
        
        # Phase 4: Encryption (main attack)
        print("[Phase 4] Starting encryption phase")
        encrypt_files()
        
        # Phase 5: Persistence (simulated by ransom note)
        print("[Phase 5] Establishing persistence")
        time.sleep(2)
        
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()
        
        log_event("simulation_complete", TARGET)
        print(f"[+] Simulation complete in {duration:.1f} seconds")
        print(f"[+] Attack artifacts in: {TARGET}")
        print(f"[+] Files to recover: {len(list(pathlib.Path(TARGET).glob('*.lockbit3')))}")
        
        # Keep pod alive for trace collection
        print("[+] Keeping pod alive for 30 seconds for trace collection...")
        time.sleep(30)
        
    except Exception as e:
        log_event("simulation_error", str(e))
        print(f"[-] Simulation error: {e}")
        raise

if __name__ == "__main__":
    main()
