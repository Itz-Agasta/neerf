# NERRF MVP Roadmap 🎯

_“Ship the smallest slice that proves AI-guided undo in the cloud”_  
**Phase**: 1 Oct 2025 → 30 Apr 2026 (≈ 7 months)

---

## 0. MVP Definition (cone of certainty)

| **What is IN**                        | **What is NOT**       |
| ------------------------------------- | --------------------- |
| Single K8s cluster (kind/minikube)    | Multi-cloud           |
| 1 ransomware scenario (LockBit-style) | Supply-chain packages |
| File-level undo                       | Network & config undo |
| CLI / Helm install                    | SaaS dashboard        |
| 60 min MTTR target                    | Auto-scaling AI       |

---

## 1. Milestones & Calendar

| Milestone                 | Dates           | Deliverable                        | Success Gate                         |
| ------------------------- | --------------- | ---------------------------------- | ------------------------------------ |
| **M0 – Research Lock-in** | 01 Oct – 15 Oct | Final threat model + data schema   | Mentor / advisor sign-off            |
| **M1 – Tracker Alpha**    | 16 Oct – 15 Dec | eBPF + gRPC stream + RocksDB       | ≥ 1 k events / sec sustained         |
| **M2 – AI Spike**         | 16 Dec – 31 Jan | GNN anomaly + LSTM predictor       | ROC-AUC ≥ 0.90 on toy set            |
| **M3 – Undo Sandbox**     | 01 Feb – 28 Feb | Firecracker rollback engine        | deterministic replay OK              |
| **M4 – Planner Glue**     | 01 Mar – 31 Mar | MCTS planner + CLI `nerrf undo`    | 1 synthetic attack undone end-to-end |
| **M5 – MVP Bundle**       | 01 Apr – 15 Apr | Helm chart + docs + demo video     | External user runs demo in < 15 min  |
| **M6 – Public Release**   | 16 Apr – 30 Apr | v0.9 tag + arXiv draft + repo open | GitHub ⭐ ≥ 50                       |

---

## 2. Weekly Cadence

| Day     | Event                   | Tool           |
| ------- | ----------------------- | -------------- |
| **Mon** | Stand-up (15 min)       | Discord `#dev` |
| **Wed** | Deep-dive sync (30 min) | Discord        |
| **Fri** | PR review + demo GIF    | GitHub Actions |

---

## 3. Detailed Sprint Backlog

### M0 – Research Lock-in (2 weeks)

- [ ] Finalise attack scenario (LockBit encrypt `/app/uploads`)
- [ ] Freeze protobuf schema (`trace.proto`)
- [ ] Freeze evaluation dataset (100 h benign + 1 h labelled attack)

### M1 – Tracker Alpha (9 weeks)

| Week  | Task                                                    |
| ----- | ------------------------------------------------------- |
| W1-W2 | eBPF probes: `vfs_write`, `vfs_open`, `clone`, `execve` |
| W3-W4 | gRPC service (`port 50051`) + Ring-buffer               |
| W5-W6 | RocksDB writer & compaction logic                       |
| W7-W8 | Prometheus metrics (`nerrf_tracker_events_total`)       |
| W9    | Load-test: 1 k events/sec on 4-core VM                  |

### M2 – AI Spike (6 weeks)

| Week  | Task                                          |
| ----- | --------------------------------------------- |
| W1-W2 | Dataset loader + PyTorch Geometric dataloader |
| W3-W4 | GraphSAGE-T model + hyper-param search        |
| W5-W6 | LSTM on edge sequences + joint loss           |
| W7    | ROC-AUC ≥ 0.90 on toy set (CI gate)           |

### M3 – Undo Sandbox (4 weeks)

| Week | Task                                  |
| ---- | ------------------------------------- |
| W1   | Firecracker rootfs (Alpine 3.19)      |
| W2   | OverlayFS + reverse-diff scripts      |
| W3   | Deterministic replay harness          |
| W4   | Safety gate (sha256 rootfs diff == 0) |

### M4 – Planner Glue (5 weeks)

| Week | Task                               |
| ---- | ---------------------------------- |
| W1   | MCTS skeleton (`mcts.py`)          |
| W2   | Reward function + graph pruning    |
| W3   | CLI `nerrf undo --id <attack>`     |
| W4   | End-to-end test (LockBit scenario) |
| W5   | CI integration (`make e2e`)        |

### M5 – MVP Bundle (2 weeks)

| Week | Task                            |
| ---- | ------------------------------- |
| W1   | Helm chart + README quick-start |
| W2   | 3-min demo GIF + blog post      |

### M6 – Public Release (2 weeks)

| Week | Task                                    |
| ---- | --------------------------------------- |
| W1   | Tag `v0.9`, release notes, Zenodo DOI   |
| W2   | Tweet, Reddit r/kubernetes, Hacker News |

---

## 4. Repository Layout (v0.9)

```
nerrf/
├── README.md
├── ROADMAP.md
├── LICENSE
├── Makefile
├── .github/
│   ├── workflows/ci.yml
│   └── workflows/demo.yml
├── tracker/
│   ├── bpf/*.bpf.c
│   ├── cmd/tracker
│   └── Dockerfile
├── ai/
│   ├── models/graphsage.py
│   ├── planner/mcts.py
│   └── requirements.txt
├── sandbox/
│   ├── vm/Dockerfile
│   └── scripts/rollback.sh
├── cli/
│   └── cmd/nerrf
├── charts/nerrf/
├── manifests/
├── datasets/
├── scripts/
│   ├── demo.sh
│   └── kind-setup.sh
└── docs/
    ├── architecture.md
    └── benchmarks.md
```

---

## 5. Developer Commands

```bash
# Install dependencies
make dev-setup      # kind, helm, bcc-tools

# Build everything
make all

# Run local demo
make demo

# Unit tests
make test

# Package Helm chart
make package
```

---

## 6. Risk Register & Mitigations

| Risk                              | Likelihood | Impact | Mitigation                    |
| --------------------------------- | ---------- | ------ | ----------------------------- |
| eBPF verifier rejects new kernels | Medium     | High   | CI matrix on 5.10 & 6.5       |
| GPU credits run out               | Medium     | Medium | Colab Pro fallback scripts    |
| Scope creep                       | High       | High   | Strict MVP definition (above) |

---

## 7. Definition of Done (per milestone)

- [ ] All acceptance gates in table above ✅
- [ ] 100 % unit-test coverage on new code ✅
- [ ] Documentation PR merged ✅
- [ ] Demo GIF or video attached ✅
- [ ] Release notes & changelog updated ✅

---

## 8. Communication Channels

- **Discord** – daily chat `#dev`
- **GitHub Projects** – kanban board
- **Weekly call** – Fridays 14:00 UTC (Discord link in README)
