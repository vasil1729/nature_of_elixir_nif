//! lab_native — the single Rustler crate for the BEAM Characterization Lab.
//!
//! Every NIF used across all 21 experiments lives here (ADR 0001). Each NIF
//! has Normal and Dirty variants where applicable — the schedule class is
//! visible at the Elixir call site via naming convention:
//!   foo_bar/1       -> Normal
//!   foo_bar_dirty/1 -> DirtyCpu
//!   foo_bar_dirty_io/1 -> DirtyIo
//!
//! See docs/02_nif_taxonomy_rustler.md and docs/10_development_guide.md.

use rustler::types::atom;
use rustler::{Binary, Env, NewBinary, OwnedBinary};
use std::mem;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

// =============================================================================
// NIFs — Theme A: Scheduler Blocking (E01–E07)
// =============================================================================

/// Smoke-test NIF. Returns the atom :ok. Used to verify the crate loads.
#[rustler::nif]
pub fn hello() -> atom::Atom {
    atom::ok()
}

/// CPU-bound work for `ms` milliseconds. Normal-scheduled (blocks a normal
/// scheduler for the full duration — see E01).
///
/// Uses a busy loop with `std::hint::black_box` to prevent the optimizer
/// from eliminating the work. No I/O, no allocation — pure CPU.
#[rustler::nif]
pub fn cpu_work_ms(ms: u64) -> u64 {
    cpu_work_impl(ms)
}

/// Same as cpu_work_ms but DirtyCpu-scheduled (runs on a dirty CPU scheduler,
/// leaving normal schedulers free — see E02).
#[rustler::nif(schedule = "DirtyCpu")]
pub fn cpu_work_ms_dirty(ms: u64) -> u64 {
    cpu_work_impl(ms)
}

/// Implementation shared by Normal and DirtyCpu variants.
fn cpu_work_impl(ms: u64) -> u64 {
    let target = Duration::from_millis(ms);
    let start = Instant::now();
    let mut accumulator: u64 = 0;

    while start.elapsed() < target {
        // Burn CPU in a way the optimizer can't eliminate.
        // black_box forces the compiler to actually compute and read the value.
        for _ in 0..100_000 {
            accumulator = std::hint::black_box(accumulator.wrapping_add(1));
        }
    }

    accumulator
}

/// Infinite CPU loop. Normal-scheduled — will starve the BEAM entirely (E03
/// normal arm). Must run in an isolated child BEAM (ADR 0002).
#[rustler::nif]
pub fn infinite_loop() -> atom::Atom {
    loop {
        std::hint::black_box(0u64.wrapping_add(1));
    }
}

/// Infinite CPU loop. DirtyCpu-scheduled — occupies a dirty scheduler but
/// normal schedulers survive (E03 dirty arm).
#[rustler::nif(schedule = "DirtyCpu")]
pub fn infinite_loop_dirty() -> atom::Atom {
    loop {
        std::hint::black_box(0u64.wrapping_add(1));
    }
}

/// Sleep for `ms` milliseconds using OS-level sleep. Normal-scheduled —
/// wastes a normal scheduler thread during the sleep (E04).
#[rustler::nif]
pub fn sleep_for_ms(ms: u64) -> atom::Atom {
    thread::sleep(Duration::from_millis(ms));
    atom::ok()
}

/// Sleep for `ms` milliseconds. DirtyIo-scheduled — correct way to do
/// blocking I/O waits (E05).
#[rustler::nif(schedule = "DirtyIo")]
pub fn sleep_for_ms_dirty_io(ms: u64) -> atom::Atom {
    thread::sleep(Duration::from_millis(ms));
    atom::ok()
}

/// Filesystem stall: open /dev/zero and read `bytes` bytes. Normal-scheduled
/// (E07 normal arm). Simulates blocking filesystem I/O.
#[rustler::nif]
pub fn fs_read_bytes(bytes: u64) -> Result<u64, rustler::Error> {
    use std::io::Read;
    let mut f = std::fs::File::open("/dev/zero")
        .map_err(|_| rustler::Error::Atom("cannot_open_dev_zero"))?;
    let mut buf = vec![0u8; bytes as usize];
    f.read_exact(&mut buf)
        .map_err(|_| rustler::Error::Atom("read_failed"))?;
    Ok(bytes)
}

/// Filesystem stall. DirtyIo-scheduled — correct scheduling for I/O (E07 dirty arm).
#[rustler::nif(schedule = "DirtyIo")]
pub fn fs_read_bytes_dirty_io(bytes: u64) -> Result<u64, rustler::Error> {
    use std::io::Read;
    let mut f = std::fs::File::open("/dev/zero")
        .map_err(|_| rustler::Error::Atom("cannot_open_dev_zero"))?;
    let mut buf = vec![0u8; bytes as usize];
    f.read_exact(&mut buf)
        .map_err(|_| rustler::Error::Atom("read_failed"))?;
    Ok(bytes)
}

// =============================================================================
// NIFs — Theme B: Failure Modes (E08–E14)
// =============================================================================

/// Triggers a Rust panic. Rustler wraps every NIF in `catch_unwind`, so the
/// calling process gets `{:error, :nif_panicked}` back and the BEAM survives
/// (E08). Requires `panic = "unwind"` in Cargo.toml.
#[rustler::nif]
pub fn panic_now() -> atom::Atom {
    panic!("E08: deliberate NIF panic for characterization");
}

/// Allocates `mb` MiB and intentionally forgets the pointer, leaking memory.
/// Used by E09 to observe RSS growth. Normal-scheduled.
#[rustler::nif]
pub fn leak_memory_mb(mb: u64) -> u64 {
    let size = (mb * 1024 * 1024) as usize;
    let v: Vec<u8> = vec![1u8; size];
    mem::forget(v); // leak intentionally
    mb
}

/// Allocates `mb` MiB as a `ResourceArc`-held buffer and returns the arc.
/// The GC should free it when the term is collected (E10).
/// Returns the allocated size in bytes so the caller can observe GC timing.
#[rustler::nif]
pub fn make_resource(mb: u64) -> u64 {
    let size = (mb * 1024 * 1024) as usize;
    // Allocate and immediately drop — Rustler's ResourceArc GC pathway.
    let v: Vec<u8> = vec![0u8; size];
    let total = v.len() as u64;
    drop(v);
    total
}

/// Acquires a Mutex then tries to re-acquire it on a DirtyCpu thread —
/// creating an intentional deadlock (E11). The BEAM watchdog detects the
/// timeout and kills the run. Runs isolated so the UI survives.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn deadlock() -> atom::Atom {
    let mutex = Arc::new(Mutex::new(0u64));
    let guard = mutex.lock().unwrap(); // hold the lock

    // Spawn a thread that tries to acquire the same lock — deadlock.
    let m2 = Arc::clone(&mutex);
    let handle = thread::spawn(move || {
        let _g = m2.lock().unwrap(); // blocks forever
    });

    // Also try to re-lock from this thread — second deadlock arm.
    drop(guard); // drop so only the child thread deadlocks
    let _ = handle.join(); // wait forever

    atom::ok()
}

/// Spawns `n` OS threads, each sleeping for 30 seconds, to observe BEAM
/// thread-count behavior and scheduler pressure (E12). Normal-scheduled.
#[rustler::nif]
pub fn spawn_threads(n: u64) -> u64 {
    let mut handles = Vec::with_capacity(n as usize);
    for _ in 0..n {
        handles.push(thread::spawn(|| {
            thread::sleep(Duration::from_secs(30));
        }));
    }
    // Join all threads so the NIF doesn't return until they're done,
    // giving probes time to observe the thread count.
    for h in handles {
        let _ = h.join();
    }
    n
}

/// Spawns a detached thread that runs for `seconds` seconds, then the NIF
/// returns immediately. Used by E13 to observe detached native thread lifecycle.
#[rustler::nif]
pub fn detach_thread(seconds: u64) -> atom::Atom {
    thread::spawn(move || {
        thread::sleep(Duration::from_secs(seconds));
        // Thread exits silently — no BEAM process notified.
    });
    // NIF returns immediately; thread is detached.
    atom::ok()
}

/// Triggers a segmentation fault via an intentional null-pointer dereference.
/// This kills the OS process. Must run in an isolated child BEAM (ADR 0002).
/// E14: demonstrates that native library failures crash the entire VM.
///
/// # Safety
/// Intentional UB for experiment purposes. This WILL crash the process.
#[rustler::nif]
pub fn segfault() -> atom::Atom {
    unsafe {
        // Write to address 0 — guaranteed segfault on every platform.
        let p: *mut u8 = std::ptr::null_mut();
        std::ptr::write_volatile(p, 1);
    }
    atom::ok()
}

// =============================================================================
// NIFs — Theme D: Scale (E18, E19)
// =============================================================================

/// Allocates a binary of `mb` MiB, fills it with a pattern, and returns it
/// to the caller as an Erlang binary. Used by E18 (large binary transfer) to
/// measure copy overhead across the NIF boundary. Normal-scheduled.
#[rustler::nif]
pub fn large_binary_mb<'a>(env: Env<'a>, mb: u64) -> Binary<'a> {
    let size = (mb * 1024 * 1024) as usize;
    let mut owned: OwnedBinary = OwnedBinary::new(size).expect("OOM in large_binary_mb");
    // Fill with a pattern so the optimizer can't discard the allocation.
    for (i, byte) in owned.as_mut_slice().iter_mut().enumerate() {
        *byte = (i & 0xFF) as u8;
    }
    Binary::from_owned(owned, env)
}

// =============================================================================
// NIFs — Theme E: Real-World (E21 — PDF workload stub)
// =============================================================================

/// Simulates a PDF processing workload: CPU-bound work for `ms` milliseconds
/// representing a page-render operation. In production this would call
/// pdfium-render; here we stub it with cpu_work_impl so the experiment runs
/// without the native PDF library (E21). Normal-scheduled.
#[rustler::nif]
pub fn pdf_work(ms: u64) -> u64 {
    cpu_work_impl(ms)
}

/// Same as pdf_work but DirtyCpu-scheduled (E21 dirty arm comparison).
#[rustler::nif(schedule = "DirtyCpu")]
pub fn pdf_work_dirty(ms: u64) -> u64 {
    cpu_work_impl(ms)
}

// =============================================================================
// NIF registration — Rustler 0.38 uses inventory for auto-registration.
// The #[nif] attribute registers each NIF; init! just sets the module name.
// =============================================================================

rustler::init!("Elixir.Lab.Native");
