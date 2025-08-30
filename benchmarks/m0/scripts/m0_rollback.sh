#!/bin/bash
# M0 Basic Rollback Test with Precise Timing and Result Storage
# Enhanced rollback script with millisecond precision and result persistence

set -e

# Configuration
POD_NAME="m0-victim"
NAMESPACE="nerrf-m0"
TARGET_DIR="/app/uploads"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

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

save_recovery_results() {
    local duration_ms=$1
    local recovered_files=$2
    local total_size_mb=$3
    
    # Create recovery results JSON
    cat > "${RESULTS_DIR}/m0_recovery_results.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S)Z",
  "platform": "minikube",
  "scale": "basic",
  "recovered_files": ${recovered_files},
  "recovery_duration_ms": ${duration_ms},
  "recovery_duration_sec": $(echo "scale=3; ${duration_ms} / 1000" | bc -l),
  "avg_recovery_per_file_ms": $(echo "scale=2; ${duration_ms} / ${recovered_files}" | bc -l 2>/dev/null || echo 0),
  "recovery_rate_fps": $(echo "scale=2; ${recovered_files} * 1000 / ${duration_ms}" | bc -l 2>/dev/null || echo 0),
  "total_size_mb": "${total_size_mb}",
  "throughput_mbps": $(echo "scale=2; ${total_size_mb} * 1000 / ${duration_ms}" | bc -l 2>/dev/null || echo 0)
}
EOF
    
    log "Recovery results saved to: ${RESULTS_DIR}/m0_recovery_results.json"
}

main() {
    log "Starting M0 enhanced rollback test with result storage..."
    
    # Ensure results directory exists
    mkdir -p "$RESULTS_DIR"
    
    # Check if pod exists
    if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
        error "Pod $POD_NAME not found in namespace $NAMESPACE"
    fi
    
    # Record start time with millisecond precision
    START_TIME_MS=$(date +%s%3N)
    START_TIME_SEC=$(date +%s)
    
    # Perform rollback with precise timing
    log "Executing M0 enhanced rollback with result capture..."
    RECOVERY_OUTPUT=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- bash -c "
        cd $TARGET_DIR || exit 1
        echo '=== M0 Enhanced Recovery Analysis ==='
        echo 'Files before rollback:'
        encrypted_count=\$(ls *.lockbit3 2>/dev/null | wc -l)
        total_size_mb=\$(du -sm . 2>/dev/null | cut -f1)
        total_size_mb=\$(du -sm . 2>/dev/null | cut -f1)
        echo \"  Encrypted files: \$encrypted_count\"
        echo \"  Total size: \${total_size_mb}MB\"
        
        if [ \$encrypted_count -eq 0 ]; then
            echo 'No encrypted files found - nothing to recover'
            echo \"RECOVERY_RESULT:0:0:\$total_size_mb\"
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
        
        echo \"RECOVERY_RESULT:\$duration_ms:\$recovered:\$total_size_mb\"
        exit 0
    ")
    
    # Extract recovery results from output
    RECOVERY_MS=$(echo "$RECOVERY_OUTPUT" | grep "RECOVERY_RESULT:" | cut -d: -f2)
    RECOVERED_FILES=$(echo "$RECOVERY_OUTPUT" | grep "RECOVERY_RESULT:" | cut -d: -f3)
    TOTAL_SIZE_MB=$(echo "$RECOVERY_OUTPUT" | grep "RECOVERY_RESULT:" | cut -d: -f4)
    
    # Record end time with millisecond precision
    END_TIME_MS=$(date +%s%3N)
    END_TIME_SEC=$(date +%s)
    DURATION_MS=$((END_TIME_MS - START_TIME_MS))
    DURATION_SEC=$((END_TIME_SEC - START_TIME_SEC))
    
    # Save detailed recovery results
    if [[ -n "$RECOVERY_MS" && -n "$RECOVERED_FILES" && -n "$TOTAL_SIZE_MB" ]]; then
        save_recovery_results "$RECOVERY_MS" "$RECOVERED_FILES" "$TOTAL_SIZE_MB"
    else
        warn "Could not extract recovery metrics, using fallback values"
        save_recovery_results "$DURATION_MS" "0" "0"
    fi
    
    log "🎯 M0 ENHANCED TIMING RESULTS:"
    log "   Recovery time: ${RECOVERY_MS:-$DURATION_MS} milliseconds"
    log "   Files recovered: ${RECOVERED_FILES:-0}"
    log "   Data recovered: ${TOTAL_SIZE_MB:-0}MB"
    log "   Total execution time: ${DURATION_MS} milliseconds (${DURATION_SEC} seconds)"
    log "   Results saved to: ${RESULTS_DIR}/m0_recovery_results.json"
    
    exit 0
}

main "$@"
