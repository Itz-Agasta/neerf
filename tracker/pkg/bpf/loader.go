// pkg/bpf/loader.go  – zero-dependency loader for M1
package bpf

import (
	"fmt"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
)

// LoadTracepoints attaches the three trace-points and returns the *ebpf.Map
// (ring-buffer) plus a slice of links for later Close().
func LoadTracepoints(objPath string) (*ebpf.Map, []link.Link, error) {
	spec, err := ebpf.LoadCollectionSpec(objPath)
	if err != nil {
		return nil, nil, fmt.Errorf("load spec: %w", err)
	}
	coll, err := ebpf.NewCollection(spec)
	if err != nil {
		return nil, nil, fmt.Errorf("new coll: %w", err)
	}
	// Pick programs by section name
	progs := map[string]string{
		"trace_openat":  "sys_enter_openat",
		"trace_write":   "sys_enter_write",
		"trace_rename":  "sys_enter_rename",
	}
	var links []link.Link
	for sec, tp := range progs {
		prog, ok := coll.Programs[sec]
		if !ok {
			continue
		}
		l, err := link.Tracepoint("syscalls", tp, prog, nil)
		if err != nil {
			return nil, nil, fmt.Errorf("attach %s: %w", tp, err)
		}
		links = append(links, l)
	}
	ringBufMap, ok := coll.Maps["events"]
	if !ok {
		return nil, nil, fmt.Errorf("events map not found")
	}
	return ringBufMap, links, nil
}