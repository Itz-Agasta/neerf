```
tracker/
├── bpf/
│   └── tracepoints.c      # openat / write / rename
├── cmd/
│   └── tracker/           # main.go (gRPC server)
├── pkg/
│   ├── bpf/               # loader, ring-buffer
│   └── pb/                # generated trace.pb.go
├── Dockerfile.minimal     # single-stage, no kernel headers needed
├── scripts/
│   └── install-deps.sh    # One-liner for dev deps
├── go.mod                 # module github.com/Itz-Agasta/NEERF/tracker
├── Makefile               # `make run` → builds + starts server
└── README.md              # quick-start for contributors
```
