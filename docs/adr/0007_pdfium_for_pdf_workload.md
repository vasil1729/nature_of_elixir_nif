# ADR 0007: pdfium-render for PDF workload

## Status

Accepted

## Context

E21 (Real PDF Workload) needs a real PDF library to process PDF files
(open, parse, watermark, render) under NIF, Dirty NIF, and Port arms. The
library choice affects what failure modes E21 can expose:

- **Pure-Rust PDF library (e.g. `lopdf`)** — safe, no C bindings, no
  segfault risk. Easy to build. But doesn't reflect the C-binding
  realities that motivate the DirtyCpu vs Port question.
- **C-backed PDF library via Rust bindings** — real-world: most production
  PDF processing uses C libraries (pdfium, mupdf, poppler). These have
  segfault risk, blocking calls, and native memory that BEAM can't see —
  exactly the failure modes E21 should expose.
- **External PDF service** — a separate process rendering PDFs. Loses the
  NIF vs Port comparison that's E21's point.

The lab's mission is to probe *real* native behavior. A pure-Rust library
would make E21 just another CPU-bound benchmark, indistinguishable from
E01/E02. The C-backed option makes E21 a genuine test of "what happens
when production PDF code runs on BEAM schedulers."

## Decision

**`pdfium-render`** (Rust bindings to Google's pdfium C library) for E21.

The Docker image fetches a pinned `libpdfium` binary at build time and
places it where `lab_native/native/build.rs` can link it. The exact pdfium
version is pinned in the Dockerfile for reproducibility.

E21 runs three arms on the same PDF files:
1. **NIF arm** — `pdf_work/2` (Normal) — likely blocks schedulers
2. **Dirty NIF arm** — `pdf_work_dirty/2` (DirtyCpu) — should isolate
3. **Port arm** — `lab_port` with `pdf_work` command — crash-isolated

Each arm processes 1000 concurrent jobs via Oban at four file sizes
(1MB, 10MB, 50MB, 100MB).

## Consequences

**Positive:**
- E21 reflects production PDF processing realistically
- C-binding failure modes (segfault, native memory) are exercisable
- Three-arm comparison (NIF vs Dirty vs Port) directly answers "when is a
  Port superior for real workloads?"

**Negative:**
- pdfium binary fetching adds Docker build complexity
- Cross-platform pdfium binaries are a pain (must match arch/glibc) —
  mitigated by pinning to a known-good binary
- Link errors are possible if the binary doesn't match the build
  environment — fallback documented in [13_runbook.md](../13_runbook.md)

**Neutral:**
- **Fallback:** if pdfium linking fails on a given platform, switch E21 to
  `mupdf-rs` (apt `libmupdf-dev` on Debian/Ubuntu). The ADR records both
  paths. The experiment's thresholds may need re-tuning on the fallback,
  documented in E21's `report.md`.
- `ring` (Rust crypto) is used for the "sign" operation in E21 — it's
  pure-Rust and doesn't need a separate decision.

## Revisited

_(none yet)_
