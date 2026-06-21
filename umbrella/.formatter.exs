[
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "apps/*/{mix,.formatter}.exs",
    "apps/*/config/*.exs",
    "apps/*/{lib,test}/**/*.{ex,exs}",
    "experiments/**/*.{ex,exs}"
  ],
  line_length: 100,
  import_deps: [:phoenix, :ecto, :telemetry],
  sub: [
    apps/*/lib/lab_web/**/*.{ex,exs}: [
      line_length: 90,
      import_deps: [:phoenix_live_view]
    ]
  ]
]
