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
#cfg(any(target="native", target="wasm"))
test "write_file appends without an explicit creation mode" {
  let path = file_test_path()
  @fs.write_file(path, b"old", sync=NoSync)
  defer @fs.remove_file(path)
  @fs.write_file(path, b"", append=true)
  debug_inspect(@fs.read_file(path), content="<Bytes: [0x6f, 0x6c, 0x64]>")
  @fs.write_file(path, b"new", append=true, sync=NoSync)
  debug_inspect(
    @fs.read_file(path),
    content="<Bytes: [0x6f, 0x6c, 0x64, 0x6e, 0x65, 0x77]>",
  )
}

///|
#cfg(any(target="native", target="wasm"))
test "new file API reuses core async OS errors" {
  let path = file_test_path() + ".missing"
  try ignore(@fs.read_file(path)) catch {
    @fs.IOError(_) => fail("new file API still raises legacy IOError")
    @os_error.OsError(kind, raw_code=code, context~) => {
      assert_eq(kind, NotFound)
      assert_not_eq(code, 0)
      assert_true(context.contains("open"))
      assert_true(context.contains(path))
      let message = @os_error.from_errno(code, context~).to_string()
      assert_false(message.contains("OS error "))
      assert_true(message.length() > context.length() + 2)
    }
    error => raise error
  } noraise {
    _ => fail("reading a missing file must fail")
  }
}

///|
#cfg(any(target="native", target="wasm"))
test "write_file append creates missing files and honors explicit truncation" {
  let path = file_test_path()
  @fs.write_file(path, b"", append=true, sync=NoSync)
  defer @fs.remove_file(path)
  assert_eq(@fs.read_file(path), b"")
  @fs.write_file(path, b"old", sync=NoSync)
  @fs.write_file(
    path,
    b"new",
    append=true,
    create_mode=CreateOrTruncate,
    sync=NoSync,
  )
  debug_inspect(@fs.read_file(path), content="<Bytes: [0x6e, 0x65, 0x77]>")
}

///|
#cfg(any(target="native", target="wasm"))
test "exact reads report UnexpectedEof and retain partial progress" {
  let path = file_test_path()
  @fs.write_file(path, b"abc", sync=NoSync)
  defer @fs.remove_file(path)
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  assert_eq(file.read_exactly(0), b"")
  for len in [4, 1] {
    try ignore(file.read_exactly(len)) catch {
      @io.UnexpectedEof as error =>
        debug_inspect(error, content="UnexpectedEof")
      error => raise error
    } noraise {
      _ => fail("expected UnexpectedEof")
    }
    assert_eq(file.read_all(), b"")
  }
  assert_eq(file.read_exactly(0), b"")
}
