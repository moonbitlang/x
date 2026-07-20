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

///|
let crypto_bench_size : Int = 64 * 1024

///|
fn crypto_bench_input() -> FixedArray[Byte] {
  FixedArray::makei(crypto_bench_size, i => (i & 0xff).to_byte())
}

///|
test "bench SHA-256 64 KiB" (it : @bench.T) {
  let input = crypto_bench_input()
  it.bench(fn() { it.keep(@crypto.sha256(input)) })
}

///|
test "bench SM3 64 KiB" (it : @bench.T) {
  let input = crypto_bench_input()
  it.bench(fn() { it.keep(@crypto.sm3(input)) })
}

///|
test "bench SHA-1 64 KiB" (it : @bench.T) {
  let input = crypto_bench_input()
  it.bench(fn() { it.keep(@crypto.sha1(input)) })
}

///|
test "bench MD5 64 KiB" (it : @bench.T) {
  let input = crypto_bench_input()
  it.bench(fn() { it.keep(@crypto.md5(input)) })
}

///|
test "bench ChaCha20 64 KiB" (it : @bench.T) {
  let key = FixedArray::make(32, b'\x00')
  let nonce = FixedArray::make(12, b'\x00')
  let input = crypto_bench_input()
  let output = FixedArray::make(crypto_bench_size, b'\x00')
  let cipher = @crypto.ChaCha::chacha20(key, nonce)
  it.bench(fn() {
    cipher.transform(input, output)
    it.keep(output)
  })
}

///|
test "bench HMAC-SHA-256 empty message" (it : @bench.T) {
  let hash = @crypto.SHA256::new()
  let key = FixedArray::make(32, b'\x88').unsafe_reinterpret_as_bytes()
  let message = b""
  it.bench(fn() { it.keep(@crypto.hmac(hash, key, message)) })
}
