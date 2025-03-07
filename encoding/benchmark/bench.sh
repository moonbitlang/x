#!/usr/bin/env bash

set -e

gtime() {
  sudo chrt -f 99 time -f '%e %M %c' $@ -a -o benchlog/bench.log 1> /dev/null
}

build_moonbit() {
  cd encoding/benchmark
  moon build --target all --release
  cd - > /dev/null
}
setup() {
  build_moonbit
  mkdir -p benchlog
  : > benchlog/bench.log
  echo "prepare sudo for chrt..."
  sudo true
}


setup

all_bench=$(find encoding/benchmark/ -type d -name '*utf*')

echo -e "\n==== wasm ===="
for bench_path in $all_bench; do
  bench_name=$(basename $bench_path)
  printf "   wasm(v8) ${bench_name}:\t" | tee -a benchlog/bench.log
  gtime "moonrun ./target/wasm/release/build/${bench_path}/${bench_name}.wasm"
  echo "" >> benchlog/bench.log
done
echo "" >> benchlog/bench.log

echo -e "\n==== wasm-gc ===="
for bench_path in $all_bench; do
  bench_name=$(basename $bench_path)
  printf "wasm-gc(v8) ${bench_name}:\t" | tee -a benchlog/bench.log
  gtime "moonrun ./target/wasm-gc/release/build/${bench_path}/${bench_name}.wasm"
  echo "" >> benchlog/bench.log
done
echo "" >> benchlog/bench.log

echo -e "\n==== js ===="
for bench_path in $all_bench; do
  bench_name=$(basename $bench_path)
  printf " js(nodejs) ${bench_name}:\t" | tee -a benchlog/bench.log
  gtime "node ./target/js/release/build/${bench_path}/${bench_name}.js"
  echo "" >> benchlog/bench.log
done
