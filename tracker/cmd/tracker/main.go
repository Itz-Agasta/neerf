package main

import (
	"bytes"
	"encoding/binary"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"

	pb "github.com/Itz-Agasta/neerf/tracker/pkg/pb"
	"github.com/cilium/ebpf/ringbuf"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
	"google.golang.org/protobuf/types/known/timestamppb"
	"github.com/Itz-Agasta/neerf/tracker/pkg/bpf"
)

func main() {
	// Get the directory of the executable (I was having some import issue prv.)
	execPath, err := os.Executable()
	if err != nil {
		log.Fatalf("get executable path: %v", err)
	}
	execDir := filepath.Dir(execPath)
	objPath := filepath.Join(execDir, "../bpf/tracepoints.o")

	// Load BPF object and attach tracepoints
	ringBufMap, links, err := bpf.LoadTracepoints(objPath)
	if err != nil {
		log.Fatalf("load tracepoints: %v", err)
	}
	defer func() {
		for _, l := range links {
			l.Close()
		}
	}()

	// Ring-buffer reader
	rd, err := ringbuf.NewReader(ringBufMap)
	if err != nil {
		log.Fatalf("ringbuf: %v", err)
	}
	defer rd.Close()

	// gRPC server
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterTrackerServer(s, &server{rd: rd})
	reflection.Register(s)
	log.Println("Tracker listening on :50051")
	go func() {
		if err := s.Serve(lis); err != nil {
			log.Fatalf("serve: %v", err)
		}
	}()

	// Graceful stop
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt)
	<-sig
	s.GracefulStop()
}

type server struct {
	pb.UnimplementedTrackerServer
	rd *ringbuf.Reader
}

func (s *server) StreamEvents(req *pb.Empty, stream pb.Tracker_StreamEventsServer) error {
	for {
		record, err := s.rd.Read()
		if err != nil {
			return err
		}
		var e event
		if err := binary.Read(bytes.NewReader(record.RawSample), binary.LittleEndian, &e); err != nil {
			continue
		}
		now := time.Now()
		pbEvent := &pb.Event{
			Ts:       timestamppb.New(now),
			Pid:      e.Pid,
			Tid:      e.Tid,
			Comm:     sanitizeString(e.Comm[:]),
			Syscall:  syscallName(e.SyscallId),
			Path:     sanitizeString(e.Path[:]),
			NewPath:  sanitizeString(e.NewPath[:]),
			RetVal:   e.RetVal,
			Bytes:    e.Bytes,
		}
		if err := stream.Send(&pb.EventBatch{Events: []*pb.Event{pbEvent}}); err != nil {
			return err
		}
	}
}

type event struct {
	Ts         uint64
	Pid        uint32
	Tid        uint32
	Comm       [16]byte
	SyscallId  uint32
	RetVal     int64
	Bytes      uint64
	Path       [256]byte
	NewPath    [256]byte
}

func syscallName(id uint32) string {
	switch id {
	case 1:
		return "openat"
	case 2:
		return "write"
	case 3:
		return "rename"
	default:
		return "unknown"
	}
}

func sanitizeString(b []byte) string {
	s := strings.TrimRight(string(b), "\x00")
	if !utf8.ValidString(s) {
		// Replace invalid UTF-8 sequences
		s = strings.ToValidUTF8(s, "?")
	}
	return s
}