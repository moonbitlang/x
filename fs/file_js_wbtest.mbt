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
extern "js" fn close_test_path() -> String =
  #| () => `tmp_fs_close_${process.pid}_${Date.now()}_${Math.random()}.bin`

///|
test "file IO preserves Node OS error codes and context" {
  let existing = close_test_path()
  defer (remove_file(existing) catch { _ => () })
  write_file(existing, b"module binding")
  assert_eq(read_file(existing), b"module binding")
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
  let explanation = os_error_message(code)
  assert_false(explanation.has_prefix("Unknown system error"))
  for message in [Show::to_string(error), "\{Repr(error)}"] {
    assert_true(message.contains(context))
    assert_true(message.contains(explanation))
  }
  debug_inspect(
    OSError(0x7fffffff, context="test"),
    content="<@fs.OSError: \"test: Unknown system error 2147483647\">",
  )
}

///|
extern "js" fn short_read(
  fd : Int32,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : NodePosition,
) -> Int32 =
  #| (fd, buffer, offset, len, position) => {
  #|   if (fd !== 7 || position !== 4294967315 || len !== 6) throw Error("invalid read arguments");
  #|   buffer.set([97, 98], offset);
  #|   return 2;
  #| }

///|
extern "js" fn short_write(
  fd : Int32,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : NodePosition,
) -> Int32 =
  #| (fd, buffer, offset, len, position) => {
  #|   if (fd !== 7 || len !== 6 || buffer[offset] !== 97) throw Error("invalid write arguments");
  #|   if (position !== null && position !== 4294967315) throw Error("invalid write position");
  #|   return 2;
  #| }

///|
test "Node adapters preserve short counts slices and positions" {
  let buffer : FixedArray[Byte] = FixedArray::make(8, 0xee)
  let read = node_read(short_read, 7, buffer, 1, 6, 4294967315)
  read.check()
  assert_eq(read.int_value(), 2)
  assert_eq(Bytes::from_array(buffer[:]), b"\xeeab\xee\xee\xee\xee\xee")
  for position in [4294967315L, APPEND_POSITION] {
    let write = node_write(short_write, 7, b"-abcdef-", 1, 6, position)
    write.check()
    assert_eq(write.int_value(), 2)
  }
}

///|
extern "js" fn fail_operation(_fd : Int32) -> Unit =
  #| _fd => { throw Object.assign(Error("injected failure"), {errno: -5}); }

///|
test "Node adapters preserve system errors" {
  for
    (result, operation) in [
      (node_sync(fail_operation, 7), "sync"),
      (node_close(fail_operation, 7), "close"),
    ] {
    try result.check() catch {
      OSError(code, context~) => {
        assert_eq(code, -5)
        assert_eq(context, operation)
      }
      error => raise error
    } noraise {
      _ => fail("expected an OS error")
    }
  }
}

///|
test "read_all handles stale hints short reads and streaming fallback" {
  for len in [0, 1, 4095, 4096, 4097, 65536, 65537] {
    let input = Bytes::makei(len, i => (i % 251).to_byte())
    for hint in [-1, 0, 1, 4096, len, len + 17] {
      let mut position = 0
      let output = read_all_with_hint(
        (buffer, offset) => {
          let n = Int32::min(
            997,
            Int32::min(buffer.length() - offset, len - position),
          )
          for i in 0..<n {
            buffer[offset + i] = input[position + i]
          }
          position += n
          n
        },
        if hint > 0 {
          Some(hint)
        } else {
          None
        },
      )
      assert_eq(output, input)
      assert_eq(position, len)
    }
  }
}

///|
test "read_all probes EOF after the size hint" {
  let requests = []
  let input = b"cdef"
  let mut position = 0
  let output = read_all_with_hint(
    (buffer, offset) => {
      requests.push(buffer.length() - offset)
      let n = Int32::min(buffer.length() - offset, input.length() - position)
      for i in 0..<n {
        buffer[offset + i] = input[position + i]
      }
      position += n
      n
    },
    Some(4),
  )
  assert_eq(output, input)
  debug_inspect(requests, content="[4, 1]")
}

///|
extern "js" fn pretend_node_platform(platform : String) -> () -> Unit =
  #| platform => {
  #|   const saved = Object.getOwnPropertyDescriptor(process, "platform");
  #|   Object.defineProperty(process, "platform", {value: platform});
  #|   return () => Object.defineProperty(process, "platform", saved);
  #| }

///|
test "Node creation permissions follow the host platform" {
  for platform in ["win32", "linux", "darwin"] {
    let restore = pretend_node_platform(platform)
    defer restore()
    for create_mode in [OpenOrCreate, CreateOrTruncate, CreateNew] {
      for permission in [0, 0o444, 0o600, 0o777] {
        let mut seen_permission = -1
        let result = node_open(
          (_path, _flags, mode) => {
            seen_permission = mode
            7
          },
          (_fd, _len) => (),
          _fd => (),
          "unused",
          WriteOnly,
          create_mode,
          false,
          permission,
        )
        result.check()
        if platform == "win32" {
          // Node maps a missing owner-write bit to FILE_ATTRIBUTE_READONLY.
          assert_true((seen_permission & 0o200) != 0)
        } else {
          assert_eq(seen_permission, permission)
        }
      }
    }
  }
}

///|
extern "js" fn fail_truncate(_fd : Int32, _len : Int32) -> Unit =
  #| () => { throw Error("injected truncate failure"); }

///|
test "Windows truncation failure closes descriptor zero once" {
  let restore = pretend_node_platform("win32")
  defer restore()
  let mut closes = 0
  let mut flags_seen = -1
  let result = node_open(
    (_path, flags, _permission) => {
      flags_seen = flags
      0
    },
    fail_truncate,
    fd => {
      closes += 1
      fail_operation(fd)
    },
    "unused",
    WriteOnly,
    TruncateExisting,
    false,
    0o644,
  )
  assert_eq(flags_seen, 1)
  assert_false(result.is_ok())
  assert_eq(result.message(), "open unused: injected truncate failure")
  assert_eq(closes, 1)
}
