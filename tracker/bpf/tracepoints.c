/* tracepoints.c  – zero-dependency, kernel 4.18+ */
#include <linux/bpf.h>
#include <linux/ptrace.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

char LICENSE[] SEC("license") = "GPL";

struct trace_event_raw_sys_enter {
    unsigned short common_type;
    unsigned char common_flags;
    unsigned char common_preempt_count;
    int common_pid;
    long int id;
    unsigned long args[6];
};

struct event {
    __u64 ts;
    __u32 pid;
    __u32 tid;
    char comm[16];
    __u32 syscall_id;   // 1=openat 2=write 3=rename
    __s64 ret_val;
    __u64 bytes;        // write only
    char path[256];
    char new_path[256]; // rename only
};

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 256 * 1024);  // 256 KB ring
} events SEC(".maps");

static __always_inline void fill_common(struct event *e, struct pt_regs *ctx) {
    e->ts   = bpf_ktime_get_ns();
    e->pid  = bpf_get_current_pid_tgid() >> 32;
    e->tid  = bpf_get_current_pid_tgid() & 0xFFFFFFFF;
    bpf_get_current_comm(&e->comm, sizeof(e->comm));
}

/* ---------- tracepoints ---------- */
SEC("tracepoint/syscalls/sys_enter_openat")
int trace_openat(struct trace_event_raw_sys_enter *ctx) {
    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) return 0;
    fill_common(e, (struct pt_regs *)ctx);
    e->syscall_id = 1;
    const char *filename = (const char *)ctx->args[1];
    bpf_probe_read_user_str(&e->path, sizeof(e->path), filename);
    bpf_ringbuf_submit(e, 0);
    return 0;
}

SEC("tracepoint/syscalls/sys_enter_write")
int trace_write(struct trace_event_raw_sys_enter *ctx) {
    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) return 0;
    fill_common(e, (struct pt_regs *)ctx);
    e->syscall_id = 2;
    e->bytes = ctx->args[2];  // count arg
    // For write, we get FD in args[0] but can't easily resolve to path in tracepoint
    //TODO: This is a known limitation - Later we will use kprobe for better path resolution
    __builtin_memset(e->path, 0, sizeof(e->path));
    bpf_ringbuf_submit(e, 0);
    return 0;
}

SEC("tracepoint/syscalls/sys_enter_rename")
int trace_rename(struct trace_event_raw_sys_enter *ctx) {
    struct event *e = bpf_ringbuf_reserve(&events, sizeof(*e), 0);
    if (!e) return 0;
    fill_common(e, (struct pt_regs *)ctx);
    e->syscall_id = 3;
    const char *oldname = (const char *)ctx->args[0];
    const char *newname = (const char *)ctx->args[1];
    bpf_probe_read_user_str(&e->path, sizeof(e->path), oldname);
    bpf_probe_read_user_str(&e->new_path, sizeof(e->new_path), newname);
    bpf_ringbuf_submit(e, 0);
    return 0;
}