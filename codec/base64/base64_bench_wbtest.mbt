// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Compare scalar and selected paths in the same executable. Timings are
// benchmarks, not snapshots or assertions, and both alphabets use the same data.

///|
let bench_bytes : Bytes = sample_bytes(65536)

///|
let bench_standard : String = encode_scalar(bench_bytes)

///|
let bench_url : String = encode_scalar(bench_bytes, url_safe=true)

///|
test "encode 64 KiB standard scalar" (it : @bench.T) {
  it.bench(fn() { it.keep(encode_scalar(bench_bytes, url_safe=false)) })
}

///|
test "encode 64 KiB standard selected" (it : @bench.T) {
  it.bench(fn() { it.keep(encode(bench_bytes, url_safe=false)) })
}

///|
test "encode 64 KiB URL-safe scalar" (it : @bench.T) {
  it.bench(fn() { it.keep(encode_scalar(bench_bytes, url_safe=true)) })
}

///|
test "encode 64 KiB URL-safe selected" (it : @bench.T) {
  it.bench(fn() { it.keep(encode(bench_bytes, url_safe=true)) })
}

///|
test "decode 64 KiB standard scalar" (it : @bench.T) {
  it.bench(fn() { it.keep(try! decode_scalar(bench_standard, url_safe=false)) })
}

///|
test "decode 64 KiB standard selected" (it : @bench.T) {
  it.bench(fn() { it.keep(try! decode(bench_standard, url_safe=false)) })
}

///|
test "decode 64 KiB URL-safe scalar" (it : @bench.T) {
  it.bench(fn() { it.keep(try! decode_scalar(bench_url, url_safe=true)) })
}

///|
test "decode 64 KiB URL-safe selected" (it : @bench.T) {
  it.bench(fn() { it.keep(try! decode(bench_url, url_safe=true)) })
}

///|
let bench_late_padding : String = bench_standard[:bench_standard.length() - 4].to_owned() +
  "Zg=" +
  "!".repeat(29)

///|
let bench_late_error : String = bench_standard[:bench_standard.length() - 4].to_owned() +
  "😀" +
  "A".repeat(30)

///|
test "decode 64 KiB prefix then early padding" (it : @bench.T) {
  it.bench(fn() { it.keep(try! decode(bench_late_padding)) })
}

///|
test "decode 64 KiB prefix then Unicode error" (it : @bench.T) {
  it.bench(fn() {
    try decode(bench_late_error) catch {
      InvalidChar(ch) => it.keep(ch)
    } noraise {
      _ => panic()
    }
  })
}
