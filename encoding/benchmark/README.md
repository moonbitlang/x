# Moonbit/Core Encoding Benchmarking

## Pre-requisites
- [hyperfine](https://github.com/sharkdp/hyperfine)

## Run

Benchmark the current state of the code
```sh
./encoding/benchmark/bench.sh
```

Benchmarks that compare code from different commits
```sh
./encoding/benchmark/bench_diff.sh HEAD~1
```
