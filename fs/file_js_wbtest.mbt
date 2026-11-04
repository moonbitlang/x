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
// A local fake handle exercises common loops without changing the real fs
// module or adding test hooks to production code.
extern "js" fn scripted_handle(scenario : String) -> FileHandle =
  #| scenario => {
  #|   const h = {fd: 0, sync: scenario === "sync_error" ? 1 : 0,
  #|     reads: 0, writes: 0, syncs: 0, closes: 0, output: []};
  #|   h.fs = {
  #|     readSync(_fd, buffer, offset, len, position) {
  #|       h.reads++;
  #|       if (scenario === "read_error" && h.reads > 1) throw Error("injected read failure");
  #|       const input = Buffer.from("abcdef");
  #|       const n = Math.min(2, len, Math.max(0, input.length - position));
  #|       buffer.set(input.subarray(position, position + n), offset);
  #|       return n;
  #|     },
  #|     writeSync(_fd, buffer, offset, len, _position) {
  #|       h.writes++;
  #|       if (scenario === "write_error" && h.writes > 1) throw Error("injected write failure");
  #|       if (scenario === "zero") return 0;
  #|       const n = Math.min(2, len);
  #|       h.output.push(...buffer.subarray(offset, offset + n));
  #|       return n;
  #|     },
  #|     fdatasyncSync() { h.syncs++; throw Error("injected sync failure"); },
  #|     closeSync() { h.closes++; if (scenario === "close_error") throw Error("injected close failure"); }
  #|   };
  #|   return h;
  #| }

///|
extern "js" fn scripted_counts(handle : FileHandle) -> FixedArray[Int32] =
  #| h => [h.reads, h.writes, h.syncs, h.closes]

///|
extern "js" fn scripted_output(handle : FileHandle) -> Bytes =
  #| h => Uint8Array.from(h.output)

///|
fn scripted_file(handle : FileHandle) -> File {
  {
    handle: Some(handle),
    mode: ReadWrite,
    append: false,
    read_position: 0,
    write_position: 0,
  }
}

///|
test "short writes finish a byte view and short reads fill read_at" {
  let handle = scripted_handle("short")
  let file = scripted_file(handle)
  defer file.close()
  file.write(b"-abcdef-"[1:7])
  assert_eq(scripted_output(handle), b"abcdef")
  assert_eq(file.write_position, 6L)
  let buffer : FixedArray[Byte] = FixedArray::make(8, 0xee)
  assert_eq(file.read_at(buffer, position=0, offset=1, len=7), 6)
  assert_eq(file.read_position, 0L)
  assert_eq(Bytes::from_array(buffer[:]), b"\xeeabcdef\xee")
  debug_inspect(scripted_counts(handle), content="<FixedArray: [4, 3, 0, 0]>")
}

///|
test "partial failures preserve cursor progress and close once" {
  for scenario in ["read_error", "write_error", "sync_error", "zero"] {
    let handle = scripted_handle(scenario)
    let file = scripted_file(handle)
    let failed = try {
      if scenario == "read_error" {
        ignore(file.read_exactly(6))
      } else {
        file.write(b"abcdef")
      }
      false
    } catch {
      IOError(_) => true
    }
    assert_true(failed)
    match scenario {
      "read_error" => assert_eq(file.read_position, 2L)
      "zero" => assert_eq(file.write_position, 0L)
      _ => assert_eq(file.write_position, 2L)
    }
    file.close()
    file.close()
    assert_eq(scripted_counts(handle)[3], 1)
    assert_true(file.handle is None)
  }
}

///|
test "close errors are available internally and never retried" {
  let handle = scripted_handle("close_error")
  let file = scripted_file(handle)
  assert_eq(file.close_result(), Some("close: injected close failure"))
  file.close()
  assert_eq(scripted_counts(handle)[3], 1)
  assert_true(file.handle is None)
  let ignored = scripted_file(scripted_handle("close_error"))
  ignored.close()
  assert_true(ignored.handle is None)
}

///|
test "JS rejects inexact positions before calling the host" {
  let handle = scripted_handle("short")
  let file = scripted_file(handle)
  defer file.close()
  let failed = try {
    file.write_at(b"a", position=9007199254740992)
    false
  } catch {
    IOError(_) => true
  }
  assert_true(failed)
  assert_eq(scripted_counts(handle)[1], 0)
}

///|
#external
priv type CloseFault

///|
// This synchronous test restores the module before the next test can run.
extern "js" fn inject_close_error() -> CloseFault =
  #| () => {
  #|   const fs = process.getBuiltinModule("fs");
  #|   const state = {fs, original: fs.closeSync, read: fs.readSync, count: 0};
  #|   fs.closeSync = fd => { state.count++; state.original(fd); throw Error("injected close failure"); };
  #|   return state;
  #| }

///|
extern "js" fn CloseFault::restore(self : CloseFault) -> Unit =
  #| state => { state.fs.closeSync = state.original; state.fs.readSync = state.read; }

///|
extern "js" fn CloseFault::fail_read(self : CloseFault) -> Unit =
  #| state => { state.fs.readSync = () => { throw Error("injected read failure"); }; }

///|
extern "js" fn CloseFault::count(self : CloseFault) -> Int32 =
  #| state => state.count

///|
extern "js" fn close_test_path() -> String =
  #| () => `tmp_fs_close_${process.pid}_${Date.now()}_${Math.random()}.bin`

///|
test "whole file helper reports close errors and preserves primary errors" {
  let path = close_test_path()
  let fault = inject_close_error()
  defer fault.restore()
  defer (remove_file(path) catch { _ => () })
  let write_error = try {
    write_file(path, b"written", sync=NoSync)
    "no error"
  } catch {
    IOError(message) => message
  }
  assert_eq(write_error, "close: injected close failure")
  assert_eq(fault.count(), 1)
  let read_error = try {
    ignore(read_file(path))
    "no error"
  } catch {
    IOError(message) => message
  }
  assert_eq(read_error, "close: injected close failure")
  assert_eq(fault.count(), 2)
  fault.fail_read()
  let primary_error = try {
    ignore(read_file(path))
    "no error"
  } catch {
    IOError(message) => message
  }
  assert_eq(primary_error, "read: injected read failure")
  assert_eq(fault.count(), 3)
}

///|
#cfg(platform="windows")
extern "js" fn failing_truncate_fs() -> NodeFs =
  #| () => ({
  #|   constants: process.getBuiltinModule("fs").constants,
  #|   closes: 0,
  #|   openSync(_path, flags) {
  #|     if (flags & this.constants.O_TRUNC) throw Error("unexpected O_TRUNC");
  #|     return 0;
  #|   },
  #|   ftruncateSync() { throw Error("injected truncate failure"); },
  #|   closeSync() { this.closes++; throw Error("injected close failure"); }
  #| })

///|
#cfg(platform="windows")
extern "js" fn truncate_close_count(fs : NodeFs) -> Int32 =
  #| fs => fs.closes

///|
#cfg(platform="windows")
test "Windows truncation failure closes once and preserves the error" {
  let fs = failing_truncate_fs()
  let result = node_open(
    fs,
    "unused",
    WriteOnly,
    TruncateExisting,
    false,
    0o644,
    NoSync,
  )
  assert_false(result.is_ok())
  assert_eq(result.message(), "open unused: injected truncate failure")
  assert_eq(truncate_close_count(fs), 1)
}
