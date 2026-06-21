# 00 — Charter

## Mission

Build a reproducible laboratory that demonstrates, measures, and documents the
runtime behavior of Elixir, Rustler NIFs, Dirty NIFs, Ports, and external
processes under failure and stress conditions.

The goal is **not** to build production code. The goal is to **experimentally
verify assumptions about BEAM behavior through controlled failures.**

## Why this exists

The Elixir community carries a body of folklore about NIFs: "NIFs are
dangerous," "long NIFs block schedulers," "use DirtyCpu for CPU work,"
"Ports are safer than NIFs," "Rustler protects you." These claims are
often true in spirit but rarely quantified:

- *How long* can a normal NIF run before degradation begins?
- *How much* latency does a 30-second normal NIF add?
- *What exactly* does Rustler catch — and what goes through it?
- *When* is a Port technically superior to a Dirty NIF, with numbers?
- *What* actually crashes the VM, as opposed to merely blocking a scheduler?

This lab answers those questions with controlled experiments, strict
assertions, and recorded evidence.

## Evidence-over-folklore principles

1. **No conclusion without an experiment.** Every claim about BEAM behavior in
   any doc, report, or commit message must cite an experiment ID (E##), a
   passing test, and recorded metrics.

2. **Documentation is a starting reference, not an authority.** Erlang/Elixir
   docs, Rustler READMEs, blog posts, and forum answers describe expected
   behavior. Experiments verify whether that behavior actually holds — and
   under what conditions it breaks.

3. **The discrepancy is the finding.** If an experiment's actual outcome
   differs from its hypothesis, record both honestly. Do not "fix" the
   hypothesis to match. The gap between expected and actual is the discovery.

4. **Reproducible by anyone.** Every experiment runs in Docker with pinned
   versions and in CI on GitHub Actions. A fork-and-verify should take one
   command.

5. **Quantitative, not anecdotal.** "Latency increases" is not a conclusion.
   "p99 latency rises from 0.3ms to 12,400ms during a 30s normal NIF" is.

6. **Failure is the signal, not a bug.** Experiments that crash the BEAM
   (E03, E08, E11, E14, E16) are designed to fail. The crash is the evidence.

## Paradigm

**Jepsen-style characterization tests.** Each experiment is an ExUnit test
with strict threshold assertions, runnable:

- **Headless** — `scripts/run_experiment.sh E##` or `mix test --only slow`
- **Interactive** — Phoenix LiveView control room at `localhost:4000`

The test passes when the BEAM's measured behavior matches the hypothesis
(within thresholds). It fails when behavior diverges — which is itself a
finding to document, not a bug to fix.

## What this lab is not

- Not a production codebase. No error handling polish, no deployment story.
- Not a benchmark suite. We measure to characterize behavior, not to rank
  implementations.
- Not a Rustler tutorial. We assume familiarity with Elixir, Rust, and NIFs.
- Not an authority on BEAM internals. We are an *observer* of BEAM behavior,
  running controlled experiments and recording what happens.

## Who this is for

- Elixir/Erlang engineers deciding between NIFs, Dirty NIFs, and Ports
- Engineers maintaining Rustler-based NIFs who want to understand failure modes
- Teams running long native operations (PDF, crypto, image, ML) on BEAM
- Anyone who has heard "NIFs are dangerous" and wants to see *why*, with numbers
