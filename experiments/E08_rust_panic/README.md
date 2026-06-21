# E08: Rust Panic (Rustler Catch Semantics)

**Theme:** B -- Failure Modes  |  **Mode:** isolated  |  **Tags:** @crash
**Related:** E14

## Hypothesis
A Rust panic! inside a NIF does NOT crash the BEAM VM. Rustler's catch_unwind wrapper converts the panic to an Erlang error, and only the calling process gets {:error, :nif_panicked}.

## Background
Rustler wraps every NIF call in std::panic::catch_unwind. With panic = "unwind" in Cargo.toml, Rust panics unwind the stack and are caught before reaching BEAM. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: Lab.Native.panic_now/0 (Normal-scheduled)
- Mode: isolated
- Cargo.toml: panic = "unwind" (required)

## Parameters
No parameters.

## Execution
- CLI: scripts/run_experiment.sh E08
- Test: mix test experiments/E08_rust_panic/

## Expected Outcome
- Calling process receives {:error, :nif_panicked}
- BEAM VM survives (exit_code = 0 from isolated child)

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E14 (segfault -- VM does NOT survive)
