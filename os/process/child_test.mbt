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

// Re-execute the test binary as a tiny child fixture. This runs before the test
// driver, only with an explicit child-only environment marker. It exercises real
// native argv and stdio on every platform without depending on a shell or Python.

///|
#cfg(not(platform="windows"))
#borrow(bytes)
extern "c" fn child_write_posix(fd : Int, bytes : Bytes, len : Int64) -> Int64 = "write"

///|
#cfg(platform="windows")
#borrow(bytes)
extern "c" fn child_write_windows(fd : Int, bytes : Bytes, len : Int) -> Int = "_write"

///|
#cfg(not(platform="windows"))
#borrow(bytes)
extern "c" fn child_read_posix(
  fd : Int,
  bytes : FixedArray[Byte],
  len : Int64,
) -> Int64 = "read"

///|
#cfg(platform="windows")
#borrow(bytes)
extern "c" fn child_read_windows(
  fd : Int,
  bytes : FixedArray[Byte],
  len : Int,
) -> Int = "_read"

///|
#cfg(platform="windows")
extern "c" fn child_set_mode(fd : Int, mode : Int) -> Int = "_setmode"

///|
#cfg(not(platform="windows"))
extern "c" fn child_signal(signal : Int) -> Int = "raise"

///|
#cfg(not(platform="windows"))
fn child_terminate() -> Unit {
  child_signal(15) |> ignore
}

///|
#cfg(platform="windows")
fn child_terminate() -> Unit {
  @sys.exit(96)
}

///|
#cfg(not(platform="windows"))
fn child_write_once(fd : Int, bytes : Bytes) -> Int {
  child_write_posix(fd, bytes, bytes.length().to_int64()).to_int()
}

///|
#cfg(platform="windows")
fn child_write_once(fd : Int, bytes : Bytes) -> Int {
  child_set_mode(fd, 0x8000) |> ignore // _O_BINARY
  child_write_windows(fd, bytes, bytes.length())
}

///|
#cfg(not(platform="windows"))
fn child_read(bytes : FixedArray[Byte]) -> Int {
  child_read_posix(0, bytes, bytes.length().to_int64()).to_int()
}

///|
#cfg(platform="windows")
fn child_read(bytes : FixedArray[Byte]) -> Int {
  child_set_mode(0, 0x8000) |> ignore
  child_read_windows(0, bytes, bytes.length())
}

///|
fn child_write(fd : Int, bytes : Bytes) -> Unit {
  let mut offset = 0
  while offset < bytes.length() {
    let written = child_write_once(fd, bytes[offset:].to_owned())
    if written <= 0 {
      @sys.exit(98)
      return
    }
    offset += written
  }
}

///|
fn child_text(s : String) -> Unit {
  child_write(1, @encoding/utf8.encode(s))
}

///|
#cfg(not(platform="windows"))
extern "c" fn child_close_fd(fd : Int) -> Int = "close"

///|
#cfg(platform="windows")
extern "c" fn child_close_fd(fd : Int) -> Int = "_close"

///|
fn child_main() -> Unit raise @os_error.OSError {
  let args = @env.args()
  match args[1] {
    "stdio_outputs" => {
      let bytes = b"skip\x00\xff\x80\r\nend"
      @stdio.stdout.write(bytes[4:4])
      @stdio.stderr.write(b"")
      @stdio.stdout.write(bytes[4:9])
      @stdio.stderr.write(bytes[5:8])
    }
    "stdio_large_outputs" => {
      let bytes = Bytes::from_array(FixedArray::make(1048576, b'x'))
      @stdio.stdout.write(bytes)
      @stdio.stderr.write(bytes)
    }
    "stdio_stdin" => child_write(1, @stdio.stdin.read_all())
    "stdio_terminals" =>
      child_text(
        "\{@stdio.stdin.is_terminal()}|\{@stdio.stdout.is_terminal()}|\{@stdio.stderr.is_terminal()}",
      )
    "bad_stdin" => {
      child_close_fd(0) |> ignore
      if @stdio.stdin.is_terminal() {
        @sys.exit(95)
      }
      (@stdio.stdin.read_all() |> ignore) catch {
        err => {
          let @os_error.OSError(_, context~) = err
          if err.is_EBADF() && context == "stdin.read_all" {
            child_text("badfd")
          } else {
            @sys.exit(95)
          }
        }
      }
    }
    "bad_stdout" => {
      child_close_fd(1) |> ignore
      if @stdio.stdout.is_terminal() {
        @sys.exit(95)
      }
      @stdio.stdout.write(b"unwritable") catch {
        err => {
          let @os_error.OSError(_, context~) = err
          if err.is_EBADF() && context == "stdout.write" {
            child_write(2, b"badfd")
          } else {
            @sys.exit(95)
          }
        }
      }
    }
    "bad_stderr" => {
      child_close_fd(2) |> ignore
      if @stdio.stderr.is_terminal() {
        @sys.exit(95)
      }
      @stdio.stderr.write(b"unwritable") catch {
        err => {
          let @os_error.OSError(_, context~) = err
          if err.is_EBADF() && context == "stderr.write" {
            child_text("badfd")
          } else {
            @sys.exit(95)
          }
        }
      }
    }
    "args" =>
      for arg in args[2:] {
        child_text(arg)
        child_write(1, b"\x00")
      }
    "both" => {
      child_write(1, b"out")
      child_write(2, b"err")
      @sys.exit(7)
    }
    "binary" => {
      child_write(1, b"\x00\xff\x80\r\n")
      child_write(2, b"\xfe\x00")
    }
    "large" => {
      let out = Bytes::from_array(FixedArray::make(65536, b'x'))
      let err = Bytes::from_array(FixedArray::make(65536, b'y'))
      for _ in 0..<32 {
        child_write(1, out)
        child_write(2, err)
      }
    }
    "env" => {
      child_text(@env.get_env_var("MOON_PROCESS_PARENT").unwrap_or("missing"))
      child_text("|")
      child_text(@env.get_env_var("MOON_PROCESS_EXTRA").unwrap_or("missing"))
    }
    "cwd" => child_text(@os.cwd())
    "copy" => {
      let buffer = FixedArray::make(4096, b'\x00')
      while true {
        let n = child_read(buffer)
        if n == 0 {
          break
        }
        if n < 0 {
          @sys.exit(98)
          break
        }
        child_write(1, Bytes::from_array(buffer)[:n].to_owned())
      }
    }
    "exit7" => @sys.exit(7)
    "buffered_exit" => {
      println("before exit")
      @sys.exit(7)
    }
    "exit259" => @sys.exit(259)
    "exit_high" => @sys.exit(-2147483647)
    "signal" => child_terminate()
    "empty" => ()
    _ => @sys.exit(97)
  }
}

///|
fn init {
  if @env.get_env_var("MOON_PROCESS_TEST_CHILD") is Some("1") {
    child_main() catch {
      _ => @sys.exit(99)
    }
    @sys.exit(0)
  }
}

///|
fn child_command() -> String raise @os_error.OSError {
  @fs.realpath(@env.args()[0])
}

///|
fn child_env(extra? : Map[String, String] = Map([])) -> Map[String, String] {
  let result = Map([("MOON_PROCESS_TEST_CHILD", "1")])
  for key, value in extra {
    result[key] = value
  }
  result
}

///|
fn expect_error(f : () -> Unit raise @os_error.OSError) -> Unit raise {
  let caught = try {
    f()
    false
  } catch {
    @os_error.OSError(code, context~) => code != 0 && !context.is_empty()
  }
  assert_true(caught)
}
