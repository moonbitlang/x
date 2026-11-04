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
test "file cursors and positional IO" {
  let path = file_test_path()
  let file = @fs.open(path, mode=ReadWrite, create_mode=CreateNew)
  defer (@fs.remove_file(path) catch { _ => () })
  defer file.close()
  file.write(b"abcdef")
  assert_eq(file.size(), 6L)
  assert_eq(file.read_exactly(2), b"ab")
  file.write_at(b"X", position=4)
  let buffer : FixedArray[Byte] = FixedArray::make(5, 0xee)
  assert_eq(file.read_at(buffer, position=4, offset=1, len=4), 2)
  debug_inspect(buffer, content="<FixedArray: [0xee, 0x58, 0x66, 0xee, 0xee]>")
  assert_eq(file.read_exactly(2), b"cd")
  file.write(b"g")
  assert_eq(file.read_all(), b"Xfg")
  assert_eq(file.read(buffer), 0)
  file.sync(only_data=true)
  file.sync()
}

///|
test "whole file helpers and byte views" {
  let path = file_test_path()
  @fs.write_file(path, b"-payload-"[1:8])
  defer (@fs.remove_file(path) catch { _ => () })
  assert_eq(@fs.read_file(path), b"payload")
  @fs.write_file(path, b"\x00\xff")
  assert_eq(@fs.read_file(path), b"\x00\xff")
  @fs.write_file(path, b"", sync=NoSync)
  assert_eq(@fs.read_file(path), b"")
  let file = @fs.create(path)
  defer file.close()
  let data = Bytes::make(150000, 0xa5)
  file.write(data)
  assert_eq(@fs.read_file(path), data)
}

///|
test "path views Unicode names and sync modes" {
  let owned_path = file_test_path() + "_月🌙"
  let wrapped = "__" + owned_path + "__"
  let path = wrapped[2:wrapped.length() - 2]
  defer (@fs.remove_file(owned_path) catch { _ => () })
  for sync in [@fs.SyncMode::NoSync, Data, Full] {
    for data in [b"\x00\xff", b""] {
      @fs.write_file(path, data, permission=0o600, sync~)
      assert_eq(@fs.read_file(path), data)
    }
  }
}

///|
test "each creating mode handles a missing file" {
  for mode in [@fs.CreateMode::OpenOrCreate, CreateOrTruncate, CreateNew] {
    let path = file_test_path()
    let file = @fs.open(path, mode=ReadWrite, create_mode=mode)
    defer (@fs.remove_file(path) catch { _ => () })
    defer file.close()
    assert_eq(file.size(), 0L)
    file.write(b"created")
    assert_eq(file.read_all(), b"created")
  }
}

///|
test "creation modes preserve or truncate contents" {
  try {
    let path = file_test_path()
    defer (@fs.remove_file(path) catch { _ => () })
    @test.assert_raise(() => {
      let f = @fs.open(path, mode=ReadWrite)
      f.close()
    })
    @test.assert_raise(() => {
      let f = @fs.open(path, mode=ReadWrite, create_mode=TruncateExisting)
      f.close()
    })
    for
      mode in [
        @fs.CreateMode::CreateNew,
        OpenExisting,
        OpenOrCreate,
        TruncateExisting,
        CreateOrTruncate,
      ] {
      let file = @fs.open(path, mode=ReadWrite, create_mode=mode)
      defer file.close()
      match mode {
        OpenExisting | OpenOrCreate => assert_eq(file.read_all(), b"seed")
        _ => assert_eq(file.size(), 0L)
      }
      file.write(b"seed")
    }
    @test.assert_raise(() => {
      let f = @fs.create(path, allow_existing=false)
      f.close()
    })
    let file = @fs.create(path)
    defer file.close()
    assert_eq(file.size(), 0L)
  } catch {
    @fs.IOError(message) => fail(message)
    error => raise error
  }
}

///|
test "truncate existing preserves the missing-file requirement" {
  for mode in [@fs.Mode::WriteOnly, ReadWrite] {
    let path = file_test_path()
    defer (@fs.remove_file(path) catch { _ => () })
    @test.assert_raise(() => {
      let file = @fs.open(path, mode~, create_mode=TruncateExisting)
      file.close()
    })
    assert_false(@fs.path_exists(path))
    @fs.write_file(path, b"seed", sync=NoSync)
    let file = @fs.open(path, mode~, create_mode=TruncateExisting) catch {
      IOError(message) => fail(message)
    }
    defer file.close()
    assert_eq(@fs.read_file(path), b"")
    file.write(b"new")
    assert_eq(@fs.read_file(path), b"new")
  }
}

///|
#cfg(target="native")
test "native supports truncating existing files in append mode" {
  let path = file_test_path()
  @fs.write_file(path, b"seed", sync=NoSync)
  defer (@fs.remove_file(path) catch { _ => () })
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=TruncateExisting,
    append=true,
  )
  defer file.close()
  assert_eq(@fs.read_file(path), b"")
  file.write(b"a")
  @fs.write_file(path, b"b", create_mode=OpenExisting, append=true, sync=NoSync)
  file.write(b"c")
  assert_eq(@fs.read_file(path), b"abc")
}

///|
test "append is independent of read cursor and sees external writes" {
  let path = file_test_path()
  @fs.write_file(path, b"start", sync=NoSync)
  defer (@fs.remove_file(path) catch { _ => () })
  let file = @fs.open(path, mode=ReadWrite, append=true)
  defer file.close()
  file.write(b"A")
  assert_eq(file.read_exactly(5), b"start")
  @fs.write_file(path, b"B", create_mode=OpenExisting, append=true, sync=NoSync)
  file.write(b"C")
  assert_eq(file.read_all(), b"ABC")
  @test.assert_raise(() => file.write_at(b"!", position=0))
  @fs.write_file(path, b"new", append=true, sync=NoSync)
  assert_eq(@fs.read_file(path), b"new")
}

///|
test "bounds access checks EOF and closure aliases" {
  let path = file_test_path()
  @fs.write_file(path, b"abc", sync=NoSync)
  defer (@fs.remove_file(path) catch { _ => () })
  let file = @fs.open(path, mode=ReadWrite)
  defer file.close()
  let buffer : FixedArray[Byte] = FixedArray::make(4, 0xee)
  @test.assert_raise(() => ignore(file.read(buffer, offset=-1)))
  @test.assert_raise(() => ignore(file.read(buffer, offset=5)))
  @test.assert_raise(() => ignore(file.read(buffer, max_len=-1)))
  @test.assert_raise(() => ignore(file.read(buffer, offset=3, max_len=2)))
  @test.assert_raise(() => ignore(file.read_at(buffer, position=-1)))
  @test.assert_raise(() => {
    ignore(file.read_at(buffer, position=0x7fffffffffffffff))
  })
  @test.assert_raise(() => ignore(file.read_exactly(-1)))
  @test.assert_raise(() => ignore(file.write_once(b"a", offset=0, len=2)))
  @test.assert_raise(() => file.write_at(b"a", position=-1))
  assert_eq(file.read(buffer, offset=4), 0)
  assert_eq(file.write_once(b"", offset=0, len=0), 0)
  file.write(b"")
  @test.assert_raise(() => ignore(file.read_exactly(5)))
  assert_eq(file.read(buffer), 0)
  let shared = file
  file.close()
  shared.close()
  @test.assert_raise(() => ignore(shared.read(buffer, max_len=0)))
  @test.assert_raise(() => shared.write(b""))
  @test.assert_raise(() => ignore(shared.size()))
  @test.assert_raise(() => shared.sync())
  let reader = @fs.open(path, mode=ReadOnly)
  defer reader.close()
  @test.assert_raise(() => reader.write(b"x"))
  let writer = @fs.open(path, mode=WriteOnly)
  defer writer.close()
  @test.assert_raise(() => ignore(writer.read(buffer)))
  @test.assert_raise(() => {
    let f = @fs.open(path, mode=ReadOnly, append=true)
    f.close()
  })
  @test.assert_raise(() => {
    let f = @fs.open(path, mode=ReadOnly, create_mode=CreateOrTruncate)
    f.close()
  })
  @test.assert_raise(() => {
    let f = @fs.open(path + "\u0000suffix", mode=ReadOnly)
    f.close()
  })
  assert_eq(@fs.read_file(path), b"abc")
}

///|
test "64 bit sparse positional IO and sliced write_once" {
  let path = file_test_path()
  let file = @fs.open(path, mode=ReadWrite, create_mode=CreateNew)
  defer (@fs.remove_file(path) catch { _ => () })
  defer file.close()
  let position = 0x100000000L + 19
  file.write_at(b"-tail-"[1:5], position~)
  assert_eq(file.size(), position + 4)
  let buffer : FixedArray[Byte] = FixedArray::make(4, 0)
  assert_eq(file.read_at(buffer, position~), 4)
  assert_eq(Bytes::from_array(buffer[:]), b"tail")
  assert_eq(file.write_once(b"-head-", offset=1, len=4), 4)
  assert_eq(file.read_exactly(4), b"head")
}
