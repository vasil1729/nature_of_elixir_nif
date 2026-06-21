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
use std::time::{Duration, Instant};

// =============================================================================
// NIFs
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

// =============================================================================
// NIF registration — Rustler 0.38 uses inventory for auto-registration.
// The #[nif] attribute registers each NIF; init! just sets the module name.
// =============================================================================

rustler::init!("Elixir.Lab.Native");
