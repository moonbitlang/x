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
extern "js" fn disable_system_error_message() -> () -> Unit =
  #| () => {
  #|   const util = process.getBuiltinModule("util");
  #|   const original = Object.getOwnPropertyDescriptor(util, "getSystemErrorMessage");
  #|   Object.defineProperty(util, "getSystemErrorMessage", {value: undefined, configurable: true});
  #|   return () => {
  #|     if (original) Object.defineProperty(util, "getSystemErrorMessage", original);
  #|     else delete util.getSystemErrorMessage;
  #|   };
  #| }

///|
test "OS errors format without getSystemErrorMessage" {
  let restore = disable_system_error_message()
  defer restore()
  let path = close_test_path() + ".missing"
  let error : OSError = try {
    ignore(read_file(path))
    fail("reading a missing file must fail")
  } catch {
    OSError(code, context~) => OSError(code, context~)
    error => raise error
  }
  let OSError(code, context~) = error
  assert_not_eq(code, 0)
  assert_true(context.contains("open"))
  assert_true(context.contains(path))
  let formatted = [error.to_string(), "\{Repr(error)}"]
  let explanation = os_error_message(code)
  assert_false(explanation.has_prefix("Unknown system error"))
  assert_true(
    explanation
    .iter()
    .any(ch => {
      (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch > '\u{7f}'
    }),
  )
  for message in formatted {
    assert_true(message.contains(context))
    assert_true(message.contains(explanation))
  }
  debug_inspect(
    OSError(0x7fffffff, context="test"),
    content="<@fs.OSError: \"test: Unknown system error 2147483647\">",
  )
}

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
extern "js" fn sized_reader(
  hint : Int32,
  input : Bytes,
  max_read : Int32,
) -> FileHandle =
  #| (hint, input, maxRead) => {
  #|   const h = {fd: 0, sync: 0, requests: []};
  #|   h.fs = {
  #|     fstatSync() {
  #|       if (hint < 0) throw Error("metadata unavailable");
  #|       return {size: BigInt(hint), isFile: () => true};
  #|     },
  #|     readSync(_fd, buffer, offset, len, position) {
  #|       h.requests.push(len);
  #|       const n = Math.min(maxRead, len, Math.max(0, input.length - position));
  #|       buffer.set(input.subarray(position, position + n), offset);
  #|       return n;
  #|     },
  #|     closeSync() {}
  #|   };
  #|   return h;
  #| }

///|
extern "js" fn read_requests(handle : FileHandle) -> FixedArray[Int32] =
  #| h => h.requests

///|
test "read_all uses the remaining size hint and probes EOF" {
  let handle = sized_reader(6, b"abcdef", 6)
  let file = scripted_file(handle)
  defer file.close()
  assert_eq(file.read_exactly(2), b"ab")
  assert_eq(file.read_all(), b"cdef")
  debug_inspect(read_requests(handle), content="<FixedArray: [2, 4, 1]>")
}

///|
test "read_all handles stale size hints short reads and streaming fallback" {
  for len in [0, 1, 4095, 4096, 4097, 65536, 65537] {
    let input = Bytes::makei(len, i => (i % 251).to_byte())
    for hint in [-1, 0, 1, 4096, len, len + 17] {
      let handle = sized_reader(hint, input, 997)
      let file = scripted_file(handle)
      defer file.close()
      assert_eq(file.read_all(), input)
      assert_eq(file.read_position, len.to_int64())
    }
  }
}

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
      Failure::Failure(_) => true
      error => raise error
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
  match file.close_result() {
    Some(Failure::Failure(message)) =>
      assert_eq(message, "close: injected close failure")
    _ => fail("expected the injected close error")
  }
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
    Failure::Failure(_) => true
    error => raise error
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
    Failure::Failure(message) => message
    error => raise error
  }
  assert_eq(write_error, "close: injected close failure")
  assert_eq(fault.count(), 1)
  let read_error = try {
    ignore(read_file(path))
    "no error"
  } catch {
    Failure::Failure(message) => message
    error => raise error
  }
  assert_eq(read_error, "close: injected close failure")
  assert_eq(fault.count(), 2)
  fault.fail_read()
  let primary_error = try {
    ignore(read_file(path))
    "no error"
  } catch {
    Failure::Failure(message) => message
    error => raise error
  }
  assert_eq(primary_error, "read: injected read failure")
  assert_eq(fault.count(), 3)
}

///|
extern "js" fn failing_truncate_fs() -> NodeFs =
  #| () => {
  #|   const platform = Object.getOwnPropertyDescriptor(process, "platform");
  #|   Object.defineProperty(process, "platform", {value: "win32"});
  #|   return {
  #|     platform,
  #|     constants: process.getBuiltinModule("fs").constants,
  #|     closes: 0,
  #|     openSync(_path, flags) {
  #|       if (flags & this.constants.O_TRUNC) throw Error("unexpected O_TRUNC");
  #|       return 0;
  #|     },
  #|     ftruncateSync() { throw Error("injected truncate failure"); },
  #|     closeSync() { this.closes++; throw Error("injected close failure"); }
  #|   };
  #| }

///|
extern "js" fn truncate_close_count(fs : NodeFs) -> Int32 =
  #| fs => fs.closes

///|
extern "js" fn restore_truncate_platform(fs : NodeFs) -> Unit =
  #| fs => { Object.defineProperty(process, "platform", fs.platform); }

///|
test "Windows truncation failure closes once and preserves the error" {
  let fs = failing_truncate_fs()
  defer restore_truncate_platform(fs)
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

///|
#external
priv type SyncProbe

///|
extern "js" fn observe_sync(fail : Bool) -> SyncProbe =
  #| fail => {
  #|   const fs = process.getBuiltinModule("fs");
  #|   const saved = {data: fs.fdatasyncSync, full: fs.fsyncSync, close: fs.closeSync};
  #|   const calls = [];
  #|   fs.fdatasyncSync = fd => {
  #|     calls.push("data");
  #|     if (fail) throw Error("injected sync failure");
  #|     saved.data(fd);
  #|   };
  #|   fs.fsyncSync = fd => {
  #|     calls.push("full");
  #|     if (fail) throw Error("injected sync failure");
  #|     saved.full(fd);
  #|   };
  #|   fs.closeSync = fd => {
  #|     calls.push("close");
  #|     saved.close(fd);
  #|     if (fail) throw Error("injected close failure");
  #|   };
  #|   return {fs, saved, calls};
  #| }

///|
extern "js" fn SyncProbe::restore(self : SyncProbe) -> Unit =
  #| ({fs, saved}) => {
  #|   fs.fdatasyncSync = saved.data;
  #|   fs.fsyncSync = saved.full;
  #|   fs.closeSync = saved.close;
  #| }

///|
extern "js" fn SyncProbe::calls(self : SyncProbe) -> FixedArray[String] =
  #| probe => probe.calls

///|
test "empty whole-file writes synchronize before closing" {
  for sync in [None, Some(NoSync), Some(Data), Some(Full)] {
    let path = close_test_path()
    write_file(path, b"seed", sync=NoSync)
    defer (remove_file(path) catch { _ => () })
    let probe = observe_sync(false)
    defer probe.restore()
    match sync {
      None => write_file(path, b"")
      Some(sync) => write_file(path, b"-"[1:], sync~)
    }
    match sync {
      Some(NoSync) =>
        debug_inspect(probe.calls(), content="<FixedArray: [\"close\"]>")
      None | Some(Data) =>
        debug_inspect(
          probe.calls(),
          content="<FixedArray: [\"data\", \"close\"]>",
        )
      Some(Full) =>
        debug_inspect(
          probe.calls(),
          content="<FixedArray: [\"full\", \"close\"]>",
        )
    }
    assert_eq(read_file(path), b"")
  }
}

///|
test "empty whole-file sync errors take precedence over close errors" {
  for sync in [Data, Full] {
    let path = close_test_path()
    write_file(path, b"seed", sync=NoSync)
    defer (remove_file(path) catch { _ => () })
    let probe = observe_sync(true)
    defer probe.restore()
    let error = try {
      write_file(path, b"", sync~)
      "no error"
    } catch {
      Failure::Failure(message) => message
      error => raise error
    }
    assert_eq(error, "sync: injected sync failure")
    match sync {
      Data =>
        debug_inspect(
          probe.calls(),
          content="<FixedArray: [\"data\", \"close\"]>",
        )
      Full =>
        debug_inspect(
          probe.calls(),
          content="<FixedArray: [\"full\", \"close\"]>",
        )
      NoSync => fail("expected a synchronization mode")
    }
  }
}
