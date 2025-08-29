#!/bin/bash
# M0 Basic Rollback Test with Precise Timing
# Default rollback script with millisecond precision (no MTTR limits)

set -e

# Configuration
POD_NAME="m0-victim"
NAMESPACE="nerrf-m0"
TARGET_DIR="/opt/data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

main() {
    log "Starting M0 basic rollback test with precise timing..."
    
    # Check if pod exists
    if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
        error "Pod $POD_NAME not found in namespace $NAMESPACE"
    fi
    
    # Record start time with millisecond precision
    START_TIME_MS=$(date +%s%3N)
    START_TIME_SEC=$(date +%s)
    
    # Perform rollback with precise timing
    log "Executing M0 basic rollback commands..."
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- bash -c "
        cd $TARGET_DIR || exit 1
        echo '=== M0 Basic Recovery Analysis ==='
        echo 'Files before rollback:'
        encrypted_count=\$(ls *.lockbit3 2>/dev/null | wc -l)
        total_size=\$(du -sh . 2>/dev/null | cut -f1)
        echo \"  Encrypted files: \$encrypted_count\"
        echo \"  Total size: \$total_size\"
        
        if [ \$encrypted_count -eq 0 ]; then
            echo 'No encrypted files found - nothing to recover'
            exit 0
        fi
        
        echo 'Starting recovery process...'
        recovered=0
        start_time_ms=\$(date +%s%3N)
        start_time_sec=\$(date +%s)
        
        for f in *.lockbit3; do
            if [ -f \"\$f\" ]; then
                base=\"\${f%.lockbit3}\"
                mv \"\$f\" \"\${base}.dat\"
                recovered=\$((recovered + 1))
                echo \"  Restored: \$f -> \${base}.dat\"
            fi
        done
        
        end_time_ms=\$(date +%s%3N)
        end_time_sec=\$(date +%s)
        duration_ms=\$((end_time_ms - start_time_ms))
        duration_sec=\$((duration_ms / 1000))
        
        echo '=== Recovery Complete ==='
        recovered_count=\$(ls *.dat 2>/dev/null | wc -l)
        echo \"  Recovered files: \$recovered_count\"
        echo \"  EXACT RECOVERY TIME: \${duration_ms} milliseconds\"
        echo \"  Equivalent: \${duration_sec} seconds\"
        
        if [ \$recovered -gt 0 ]; then
            avg_ms=\$(echo \"scale=2; \$duration_ms / \$recovered\" | bc -l 2>/dev/null || echo \"N/A\")
            rate_fps=\$(echo \"scale=2; \$recovered * 1000 / \$duration_ms\" | bc -l 2>/dev/null || echo \"N/A\")
            echo \"  Average per file: \${avg_ms} ms\"
            echo \"  Recovery rate: \${rate_fps} files/second\"
        fi
        
        exit 0
    "
    
    # Record end time with millisecond precision
    END_TIME_MS=$(date +%s%3N)
    END_TIME_SEC=$(date +%s)
    DURATION_MS=$((END_TIME_MS - START_TIME_MS))
    DURATION_SEC=$((END_TIME_SEC - START_TIME_SEC))
    
    log "🎯 M0 PRECISE TIMING RESULTS:"
    log "   Total execution time: ${DURATION_MS} milliseconds (${DURATION_SEC} seconds)"
    log "   No MTTR limits applied - this is real performance data"
    log "   Basic dataset: 25 files, ~14MB"
    
    exit 0
}

main "$@"
