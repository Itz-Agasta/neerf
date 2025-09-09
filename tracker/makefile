# Makefile  – zero-surprise build
SHELL        := /bin/bash
CLANG        ?= clang
KERNELRELEASE := $(shell uname -r)
BPF_OBJ      := bpf/tracepoints.o
TRACKER_BIN  := bin/tracker
DOCKER_TAG   := nerrf/tracker:m1

.PHONY: all clean bpf tracker docker test

all: bpf tracker

bpf: $(BPF_OBJ)
$(BPF_OBJ): bpf/tracepoints.c
	@mkdir -p bpf bin
	$(CLANG) -O2 -g -target bpf -c $< -o $@

tracker: $(TRACKER_BIN)
$(TRACKER_BIN): go.mod $(shell find . -name '*.go')
	go mod tidy
	go build -o $@ ./cmd/tracker

docker:
	docker build -f Dockerfile.minimal -t $(DOCKER_TAG) .

test: docker
	./scripts/test.sh   # spins minikube + LockBit sim

clean:
	rm -rf bin/ bpf/*.o