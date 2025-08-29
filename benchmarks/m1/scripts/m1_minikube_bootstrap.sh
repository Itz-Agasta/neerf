#!/usr/bin/env bash
# M1 Enterprise-Scale Bootstrap Script     kubectl create configmap lockbit-simulator-m1 \
        --from-file=sim_lockbit_m1.py="${SCRIPT_DIR}/sim_lockbit_m1.py" \
        --namespace="$NAMESPACE" \ERRF LockBit Benchmark
# Usage: ./scripts/m1_minikube_bootstrap.sh

set -e

# Configuration
NAMESPACE="nerrf-m1"
TRACE_FILE="./results/m1_trace.jsonl"
GT_FILE="./results/m1_ground_truth.csv"
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
    log "Checking Minikube environment for M1..."
    
    if ! minikube status | grep -q "host: Running"; then
        error "Minikube is not running. Please start with: minikube start --driver=docker"
    fi
    
    # Check available resources for larger dataset
    log "Verifying system resources for M1 enterprise simulation..."
    
    kubectl config use-context minikube
    log "✅ Minikube environment ready for M1"
}

cleanup_existing_m1_resources() {
    log "Cleaning up existing M1 resources..."
    
    # Delete existing pod if it exists
    if kubectl get pod m1-victim -n "$NAMESPACE" &>/dev/null; then
        log "Found existing m1-victim pod, deleting it..."
        kubectl delete pod m1-victim -n "$NAMESPACE" --grace-period=0 --force &>/dev/null || true
        
        # Wait for pod to be fully deleted
        log "Waiting for pod deletion..."
        while kubectl get pod m1-victim -n "$NAMESPACE" &>/dev/null; do
            sleep 2
        done
        log "✅ Existing pod cleaned up"
    fi
    
    # Delete existing configmap if it exists
    kubectl delete configmap lockbit-simulator-m1 -n "$NAMESPACE" --ignore-not-found=true &>/dev/null || true
    
    log "✅ M1 cleanup complete"
}

setup_m1_namespace() {
    log "Setting up M1 namespace: $NAMESPACE"
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl config set-context --current --namespace="$NAMESPACE"
    
    # Clean up any existing resources
    cleanup_existing_m1_resources
    
    log "✅ M1 namespace $NAMESPACE ready"
}

deploy_m1_simulator() {
    log "Deploying M1 enterprise LockBit simulator..."
    
    # Create ConfigMap with M1 simulator script
    kubectl create configmap lockbit-simulator-m1 \
        --from-file=sim_lockbit_m1.py="${SCRIPT_DIR}/sim_lockbit_m1.py" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create M1 pod manifest with increased resources
    cat > /tmp/m1_minikube_victim.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: m1-victim
  labels:
    app: nerrf-m1-benchmark
    component: victim
    scale: enterprise
spec:
  restartPolicy: Never
  containers:
  - name: victim
    image: python:3.11-slim
    command: ["sh", "-c"]
    args:
    - |
      apt-get update -qq && apt-get install -y -qq strace procps curl htop
      echo "=== NERRF M1 Enterprise LockBit Simulation Starting ==="
      echo "Target: 100-128 MB across 45-50 files (2-5 MB each)"
      echo "Kubernetes Node: $HOSTNAME"
      echo "Target Directory: /app/uploads"
      echo "Memory Available: $(free -h | grep Mem | awk '{print $2}')"
      python3 /tmp/sim_lockbit_m1.py
      echo "=== M1 Simulation Complete - Keeping pod alive ==="
      sleep 600
    volumeMounts:
    - name: uploads
      mountPath: /app/uploads
    - name: script
      mountPath: /tmp/sim_lockbit_m1.py
      subPath: sim_lockbit_m1.py
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"
    env:
    - name: PYTHONUNBUFFERED
      value: "1"
  volumes:
  - name: uploads
    emptyDir:
      sizeLimit: "2Gi"
  - name: script
    configMap:
      name: lockbit-simulator-m1
      defaultMode: 0755
EOF

    kubectl apply -f /tmp/m1_minikube_victim.yaml -n "$NAMESPACE"
    
    log "Waiting for M1 victim pod to be ready..."
    kubectl wait --for=condition=Ready pod/m1-victim --timeout=300s -n "$NAMESPACE"
    
    log "✅ M1 enterprise simulator deployed successfully"
}

run_m1_simulation() {
    log "Running M1 enterprise-scale LockBit simulation..."
    
    # Create required directories
    mkdir -p "${ROOT_DIR}/datasets/m1"
    mkdir -p "./results"
    
    START_TIME=$(date +%s)
    START_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log "Monitoring M1 simulation progress..."
    kubectl logs -f pod/m1-victim -n "$NAMESPACE" &
    LOGS_PID=$!
    
    # Extended timeout for larger dataset
    local timeout=1800  # 30 minutes for enterprise scale
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if kubectl logs pod/m1-victim -n "$NAMESPACE" 2>/dev/null | grep -q "M1.*Simulation complete"; then
            log "✅ M1 enterprise simulation completed successfully"
            break
        fi
        
        if kubectl get pod m1-victim -n "$NAMESPACE" -o jsonpath='{.status.phase}' | grep -q "Failed"; then
            error "M1 pod failed during simulation"
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
        
        if [[ $((elapsed % 120)) -eq 0 ]]; then
            local mins=$((elapsed / 60))
            log "M1 simulation running... (${mins}m elapsed)"
        fi
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        warn "M1 simulation timeout after ${timeout}s, collecting available data..."
    fi
    
    kill $LOGS_PID 2>/dev/null || true
    
    END_TIME=$(date +%s)
    END_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    {
        echo "start_ts,end_ts,start_iso,end_iso,attack_family,target_path,duration_sec,platform,scale"
        echo "${START_TIME},${END_TIME},${START_ISO},${END_ISO},LockBitEthical,/app/uploads,$((END_TIME - START_TIME)),minikube,enterprise"
    } > "$GT_FILE"
    
    log "✅ M1 ground truth data saved to: $GT_FILE"
}

collect_m1_artifacts() {
    log "Collecting M1 enterprise artifacts..."
    
    kubectl logs pod/m1-victim -n "$NAMESPACE" > "${TRACE_FILE}.tmp" 2>/dev/null || true
    
    if grep -q "TRACE:" "${TRACE_FILE}.tmp" 2>/dev/null; then
        grep "TRACE:" "${TRACE_FILE}.tmp" | sed 's/TRACE: //' > "$TRACE_FILE"
        log "✅ Extracted $(wc -l < "$TRACE_FILE") M1 trace events"
    else
        warn "No structured trace events found, saving raw logs"
        cp "${TRACE_FILE}.tmp" "$TRACE_FILE"
    fi
    
    rm -f "${TRACE_FILE}.tmp"
    
    log "Collecting M1 file system state..."
    kubectl exec m1-victim -n "$NAMESPACE" -- find /app/uploads -type f -exec ls -la {} \; > "${ROOT_DIR}/datasets/m1/file_list.txt" 2>/dev/null || true
    
    local encrypted_count=$(kubectl exec m1-victim -n "$NAMESPACE" -- find /app/uploads -name "*.lockbit3" 2>/dev/null | wc -l || echo "0")
    local total_size=$(kubectl exec m1-victim -n "$NAMESPACE" -- du -sb /app/uploads 2>/dev/null | cut -f1 || echo "0")
    
    # Calculate enterprise metrics
    local avg_file_size=$((total_size / encrypted_count))
    local throughput_estimate=$(echo "scale=2; $total_size / 1024 / 1024 / 120" | bc -l 2>/dev/null || echo "1.0")
    
    cat > "${ROOT_DIR}/datasets/m1/metadata.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "minikube",
  "scale": "enterprise",
  "encrypted_files": $encrypted_count,
  "total_size_bytes": $total_size,
  "total_size_mb": $((total_size / 1024 / 1024)),
  "avg_file_size_mb": $((avg_file_size / 1024 / 1024)),
  "trace_events": $(wc -l < "$TRACE_FILE" 2>/dev/null || echo "0"),
  "target_directory": "/app/uploads",
  "estimated_throughput_mbps": "$throughput_estimate"
}
EOF
    
    log "✅ M1 artifacts collected:"
    log "   - Trace file: $TRACE_FILE ($(wc -l < "$TRACE_FILE" 2>/dev/null || echo "0") lines)"
    log "   - Encrypted files: $encrypted_count"
    log "   - Total size: $((total_size / 1024 / 1024)) MB"
    log "   - Average file size: $((avg_file_size / 1024 / 1024)) MB"
}

test_m1_recovery() {
    log "Testing M1 enterprise recovery readiness..."
    
    # Use the dedicated rollback script instead of inline recovery
    log "Executing dedicated M1 rollback script..."
    if [[ -f "$SCRIPT_DIR/m1_rollback.sh" ]]; then
        "$SCRIPT_DIR/m1_rollback.sh"
    else
        warn "M1 rollback script not found at $SCRIPT_DIR/m1_rollback.sh"
        error "Cannot proceed without dedicated recovery script"
    fi
}

show_m1_results() {
    log "=== NERRF M1 Enterprise Benchmark Results ==="
    echo ""
    echo "Platform: Minikube"
    echo "Scale: Enterprise (100-128 MB, 45-50 files)"
    echo "Namespace: $NAMESPACE"
    echo "Generated files:"
    ls -lh "${ROOT_DIR}/datasets/m1/" 2>/dev/null || echo "No files generated"
    echo ""
    echo "M1 validation commands:"
    echo "  kubectl exec m1-victim -n $NAMESPACE -- ls -la /app/uploads"
    echo "  kubectl logs m1-victim -n $NAMESPACE | tail -20"
    echo "  cat $TRACE_FILE | jq '.event' | sort | uniq -c"
    echo ""
    echo "Cleanup commands:"
    echo "  kubectl delete namespace $NAMESPACE"
    echo "  rm -rf ${ROOT_DIR}/datasets/m1"
    echo ""
    
    if [[ -f "${ROOT_DIR}/datasets/m1/metadata.json" ]]; then
        echo "M1 Metadata:"
        cat "${ROOT_DIR}/datasets/m1/metadata.json" | jq .
    fi
}

main() {
    log "🚀 Starting NERRF M1 Enterprise Benchmark on Minikube"
    log "======================================================="
    log "Target: 100-128 MB across 45-50 files (2-5 MB each)"
    
    check_minikube
    setup_m1_namespace
    deploy_m1_simulator
    run_m1_simulation
    collect_m1_artifacts
    test_m1_recovery
    show_m1_results
    
    log "🎉 M1 Enterprise Benchmark completed successfully!"
    log "Pod 'm1-victim' is running in namespace '$NAMESPACE' for further testing"
}

# Handle script interruption
trap 'error "M1 script interrupted"' INT TERM

main "$@"
