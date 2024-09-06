type XStringCreateHandle

type XStringReadHandle

pub type XExternString

fn begin_create_string() -> XStringCreateHandle = "__moonbit_fs_unstable" "begin_create_string"

fn string_append_char(handle : XStringCreateHandle, ch : Char) = "__moonbit_fs_unstable" "string_append_char"

fn finish_create_string(handle : XStringCreateHandle) -> XExternString = "__moonbit_fs_unstable" "finish_create_string"

pub fn string_to_extern(s : String) -> XExternString {
  let handle = begin_create_string()
  s.iter().each(fn(ch) { string_append_char(handle, ch) })
  finish_create_string(handle)
}

fn begin_read_string(s : XExternString) -> XStringReadHandle = "__moonbit_fs_unstable" "begin_read_string"

/// Read one char from the string, returns -1 if the end of the string is reached.
/// The number returned is the unicode codepoint of the character.
fn string_read_char(handle : XStringReadHandle) -> Int = "__moonbit_fs_unstable" "string_read_char"

fn finish_read_string(handle : XStringReadHandle) = "__moonbit_fs_unstable" "finish_read_string"

pub fn string_from_extern(e : XExternString) -> String {
  let buf = Buffer::new()
  let handle = begin_read_string(e)
  while true {
    let ch = string_read_char(handle)
    if ch == -1 {
      break
    } else {
      buf.write_char(Char::from_int(ch))
    }
  }
  finish_read_string(handle)
  buf.to_string()
}
