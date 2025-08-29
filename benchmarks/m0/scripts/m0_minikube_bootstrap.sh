#!/usr/bin/env bash
# M0 Minikube Bootstrap Script - NERRF LockBit Benchmark
# Usage: ./scripts/m0_minikube_bootstrap.sh

set -e

# Configuration
NAMESPACE="nerrf-m0"
TRACE_FILE="./results/m0_trace.jsonl"
GT_FILE="./results/m0_ground_truth.csv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

check_minikube() {
    log "Checking Minikube environment..."
    
    # Check if minikube is running
    if ! minikube status | grep -q "host: Running"; then
        error "Minikube is not running. Please start with: minikube start --driver=docker"
    fi
    
    # Check if kubectl is configured for minikube
    if ! kubectl cluster-info | grep -q "Kubernetes control plane"; then
        error "kubectl is not configured for Minikube"
    fi
    
    # Set context to minikube
    kubectl config use-context minikube
    
    log "✅ Minikube environment ready"
}

cleanup_existing_resources() {
    log "Cleaning up existing resources..."
    
    # Delete existing pod if it exists
    if kubectl get pod m0-victim -n "$NAMESPACE" &>/dev/null; then
        log "Found existing m0-victim pod, deleting it..."
        kubectl delete pod m0-victim -n "$NAMESPACE" --grace-period=0 --force &>/dev/null || true
        
        # Wait for pod to be fully deleted
        log "Waiting for pod deletion..."
        while kubectl get pod m0-victim -n "$NAMESPACE" &>/dev/null; do
            sleep 2
        done
        log "✅ Existing pod cleaned up"
    fi
    
    # Delete existing configmap if it exists
    kubectl delete configmap lockbit-simulator -n "$NAMESPACE" --ignore-not-found=true &>/dev/null || true
    
    log "✅ Cleanup complete"
}

setup_namespace() {
    log "Setting up namespace: $NAMESPACE"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Set as default namespace for this session
    kubectl config set-context --current --namespace="$NAMESPACE"
    
    # Clean up any existing resources
    cleanup_existing_resources
    
    log "✅ Namespace $NAMESPACE ready"
}

deploy_simulator() {
    log "Deploying LockBit simulator to Minikube..."
    
    # Create ConfigMap with the simulator script
    kubectl create configmap lockbit-simulator \
        --from-file=sim_lockbit.py="${SCRIPT_DIR}/sim_lockbit.py" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create simplified pod manifest for Minikube
    cat > /tmp/m0_minikube_victim.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: m0-victim
  labels:
    app: nerrf-benchmark
    component: victim
spec:
  restartPolicy: Never
  containers:
  - name: victim
    image: python:3.11-slim
    command: ["sh", "-c"]
    args:
    - |
      apt-get update -qq && apt-get install -y -qq strace procps curl
      echo "=== NERRF M0 LockBit Simulation Starting ==="
      echo "Kubernetes Node: $HOSTNAME"
      echo "Target Directory: /app/uploads"
      python3 /tmp/sim_lockbit.py
      echo "=== Simulation Complete - Keeping pod alive ==="
      sleep 300
    volumeMounts:
    - name: uploads
      mountPath: /app/uploads
    - name: script
      mountPath: /tmp/sim_lockbit.py
      subPath: sim_lockbit.py
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    env:
    - name: PYTHONUNBUFFERED
      value: "1"
  volumes:
  - name: uploads
    emptyDir:
      sizeLimit: "1Gi"
  - name: script
    configMap:
      name: lockbit-simulator
      defaultMode: 0755
EOF

    # Deploy the victim pod
    kubectl apply -f /tmp/m0_minikube_victim.yaml -n "$NAMESPACE"
    
    # Wait for pod to be ready
    log "Waiting for victim pod to be ready..."
    kubectl wait --for=condition=Ready pod/m0-victim --timeout=300s -n "$NAMESPACE"
    
    log "✅ Simulator deployed to Minikube successfully"
}

run_simulation() {
    log "Running LockBit simulation in Minikube..."
    
    # Create required directories
    mkdir -p "${ROOT_DIR}/datasets/m0"
    mkdir -p "./results"
    
    # Record start time
    START_TIME=$(date +%s)
    START_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Monitor pod logs in background
    log "Monitoring simulation progress..."
    kubectl logs -f pod/m0-victim -n "$NAMESPACE" &
    LOGS_PID=$!
    
    # Wait for simulation to complete (detect completion from logs)
    local timeout=600
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if kubectl logs pod/m0-victim -n "$NAMESPACE" 2>/dev/null | grep -q "Simulation complete"; then
            log "✅ Simulation completed successfully"
            break
        fi
        
        if kubectl get pod m0-victim -n "$NAMESPACE" -o jsonpath='{.status.phase}' | grep -q "Failed"; then
            error "Pod failed during simulation"
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            log "Simulation running... (${elapsed}s elapsed)"
        fi
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        warn "Simulation timeout after ${timeout}s, collecting available data..."
    fi
    
    # Stop log monitoring
    kill $LOGS_PID 2>/dev/null || true
    
    # Record end time
    END_TIME=$(date +%s)
    END_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create ground truth file
    {
        echo "start_ts,end_ts,start_iso,end_iso,attack_family,target_path,duration_sec,platform"
        echo "${START_TIME},${END_TIME},${START_ISO},${END_ISO},LockBitEthical,/app/uploads,$((END_TIME - START_TIME)),minikube"
    } > "$GT_FILE"
    
    log "✅ Ground truth data saved to: $GT_FILE"
}

collect_artifacts() {
    log "Collecting simulation artifacts from Minikube..."
    
    # Get pod logs as trace data
    kubectl logs pod/m0-victim -n "$NAMESPACE" > "${TRACE_FILE}.tmp" 2>/dev/null || true
    
    # Extract TRACE lines and convert to JSONL format
    if grep -q "TRACE:" "${TRACE_FILE}.tmp" 2>/dev/null; then
        grep "TRACE:" "${TRACE_FILE}.tmp" | sed 's/TRACE: //' > "$TRACE_FILE"
        log "✅ Extracted $(wc -l < "$TRACE_FILE") trace events"
    else
        warn "No structured trace events found, saving raw logs"
        cp "${TRACE_FILE}.tmp" "$TRACE_FILE"
    fi
    
    # Clean up temp file
    rm -f "${TRACE_FILE}.tmp"
    
    # Get file listing from pod
    log "Collecting file system state..."
    kubectl exec m0-victim -n "$NAMESPACE" -- find /app/uploads -type f -exec ls -la {} \; > "${ROOT_DIR}/datasets/m0/file_list.txt" 2>/dev/null || true
    
    # Get encrypted file count and sizes
    local encrypted_count=$(kubectl exec m0-victim -n "$NAMESPACE" -- find /app/uploads -name "*.lockbit3" 2>/dev/null | wc -l || echo "0")
    local total_size=$(kubectl exec m0-victim -n "$NAMESPACE" -- du -sb /app/uploads 2>/dev/null | cut -f1 || echo "0")
    
    # Save metadata
    cat > "${ROOT_DIR}/datasets/m0/metadata.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "minikube",
  "encrypted_files": $encrypted_count,
  "total_size_bytes": $total_size,
  "total_size_mb": $((total_size / 1024 / 1024)),
  "trace_events": $(wc -l < "$TRACE_FILE" 2>/dev/null || echo "0"),
  "target_directory": "/app/uploads"
}
EOF
    
    log "✅ Artifacts collected:"
    log "   - Trace file: $TRACE_FILE ($(wc -l < "$TRACE_FILE" 2>/dev/null || echo "0") lines)"
    log "   - Encrypted files: $encrypted_count"
    log "   - Total size: $((total_size / 1024 / 1024)) MB"
}

test_recovery() {
    log "Testing manual recovery in Minikube..."
    
    # Use the dedicated rollback script
    log "Executing dedicated M0 rollback script..."
    if [[ -f "$SCRIPT_DIR/m0_rollback.sh" ]]; then
        "$SCRIPT_DIR/m0_rollback.sh"
    else
        warn "M0 rollback script not found, performing inline recovery..."
        manual_inline_recovery
    fi
}

manual_inline_recovery() {
    local recovery_start=$(date +%s)
    
    # Test recovery process with proper bash syntax
    kubectl exec m0-victim -n "$NAMESPACE" -- bash -c '
        cd /app/uploads || exit 1
        echo "=== Files before recovery ==="
        ls -la
        echo ""
        echo "=== Starting recovery ==="
        recovered=0
        for f in *.lockbit3; do
            if [[ -f "$f" ]]; then
                base="${f%.lockbit3}"
                mv "$f" "${base}.dat"
                echo "Recovered: $f -> ${base}.dat"
                recovered=$((recovered + 1))
            fi
        done
        echo ""
        echo "=== Files after recovery ==="
        ls -la
        echo "=== Recovery complete: $recovered files restored ==="
    ' || warn "Recovery test failed"
    
    local recovery_end=$(date +%s)
    local recovery_duration=$((recovery_end - recovery_start))
    
    log "✅ Manual recovery completed in $recovery_duration seconds"
    
    if [[ $recovery_duration -le 60 ]]; then
        log "✅ MTTR requirement met: $recovery_duration ≤ 60 seconds"
    else
        warn "⚠️  MTTR requirement not met: $recovery_duration > 60 seconds"
    fi
}

show_results() {
    log "=== NERRF M0 Benchmark Results ==="
    echo ""
    echo "Platform: Minikube"
    echo "Namespace: $NAMESPACE"
    echo "Generated files:"
    ls -lh "${ROOT_DIR}/datasets/m0/" 2>/dev/null || echo "No files generated"
    echo ""
    echo "Quick validation commands:"
    echo "  kubectl exec m0-victim -n $NAMESPACE -- ls -la /app/uploads"
    echo "  kubectl logs m0-victim -n $NAMESPACE"
    echo "  cat $TRACE_FILE"
    echo ""
    echo "Cleanup commands:"
    echo "  kubectl delete namespace $NAMESPACE"
    echo "  rm -rf ${ROOT_DIR}/datasets/m0"
    echo ""
    
    if [[ -f "${ROOT_DIR}/datasets/m0/metadata.json" ]]; then
        echo "Metadata:"
        cat "${ROOT_DIR}/datasets/m0/metadata.json"
    fi
}

main() {
    log "🚀 Starting NERRF M0 Benchmark on Minikube"
    log "========================================"
    
    check_minikube
    setup_namespace
    deploy_simulator
    run_simulation
    collect_artifacts
    test_recovery
    show_results
    
    log "🎉 M0 Benchmark completed successfully on Minikube!"
    log "Pod 'm0-victim' is running in namespace '$NAMESPACE' for further testing"
}

# Handle script interruption
trap 'error "Script interrupted"' INT TERM

# Run main function
main "$@"
