//! lab_port — the single Rust port binary for the BEAM Characterization Lab.
//!
//! Reads newline-delimited JSON from stdin, writes newline-delimited JSON to
//! stdout. One request per line; one response per request.
//!
//! Protocol spec: docs/09_architecture.md
//! Used by: E17 (crash isolation comparison), E21 (PDF Port arm)
//!
//! Commands (added per-experiment):
//!   cpu_work  — CPU-bound work for `ms` milliseconds (shared with NIF E01)
//!   quit      — clean shutdown

use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};
use std::time::{Duration, Instant};

#[derive(Deserialize, Debug)]
struct Request {
    cmd: String,
    #[serde(default)]
    id: Option<String>,
    #[serde(default)]
    ms: Option<u64>,
    #[serde(default)]
    mb: Option<u64>,
}

#[derive(Serialize, Debug)]
struct Response {
    id: String,
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    duration_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

impl Response {
    #[allow(dead_code)]
    fn ok(id: &str) -> Self {
        Response { id: id.to_string(), ok: true, duration_ms: None, error: None }
    }

    fn ok_with_duration(id: &str, ms: u64) -> Self {
        Response { id: id.to_string(), ok: true, duration_ms: Some(ms), error: None }
    }

    fn err(id: &str, msg: &str) -> Self {
        Response { id: id.to_string(), ok: false, duration_ms: None, error: Some(msg.to_string()) }
    }
}

fn main() {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => {
                let _ = writeln!(out, r#"{{"id":"","ok":false,"error":"io: {e}"}}"#);
                break;
            }
        };

        if line.trim().is_empty() {
            continue;
        }

        let req: Request = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                let _ = writeln!(
                    out,
                    r#"{{"id":"","ok":false,"error":"invalid json: {e}"}}"#
                );
                continue;
            }
        };

        let id = req.id.unwrap_or_default();

        match req.cmd.as_str() {
            "cpu_work" => {
                let ms = req.ms.unwrap_or(1000);
                let start = Instant::now();
                cpu_work_impl(ms);
                let elapsed = start.elapsed().as_millis() as u64;
                let resp = Response::ok_with_duration(&id, elapsed);
                let _ = writeln!(out, "{}", serde_json::to_string(&resp).unwrap());
            }

            "quit" => break,

            cmd => {
                let resp = Response::err(&id, &format!("unknown_command: {cmd}"));
                let _ = writeln!(out, "{}", serde_json::to_string(&resp).unwrap());
            }
        }

        let _ = out.flush();
    }
}

/// CPU-bound work — same algorithm as lab_native's cpu_work_impl.
fn cpu_work_impl(ms: u64) {
    let target = Duration::from_millis(ms);
    let start = Instant::now();
    let mut accumulator: u64 = 0;

    while start.elapsed() < target {
        for _ in 0..100_000 {
            accumulator = std::hint::black_box(accumulator.wrapping_add(1));
        }
    }
}
