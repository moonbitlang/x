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
fn encode_segment(bytes : Bytes) -> String {
  @base64.encode(bytes, padding=false)
  .replace_all(old="+", new="-")
  .replace_all(old="/", new="_")
}

///|
fn decode_base64url(segment : StringView) -> Bytes raise JwtError {
  // decode_at checks the token's alphabet before splitting it into segments.
  let standard = segment
    .to_owned()
    .replace_all(old="-", new="+")
    .replace_all(old="_", new="/")
  @base64.decode(standard) catch {
    _ => raise InvalidToken("JWT segment is not valid Base64URL")
  }
}

///|
fn is_valid_utf16(text : String) -> Bool {
  // MoonBit strings can contain unpaired UTF-16 surrogates. The native UTF-8
  // encoder assumes well-formed UTF-16, so reject malformed input first.
  for units = text.code_units() {
    match units {
      [] => break true
      [0xD800..=0xDBFF, 0xDC00..=0xDFFF, .. rest] => continue rest
      [0xD800..=0xDFFF, ..] => break false
      [_, .. rest] => continue rest
    }
  }
}

///|
fn parse_jwt_json(bytes : Bytes) -> Json raise JwtError {
  let text = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise InvalidToken("JWT JSON is not valid UTF-8")
  }
  @json.parse(text) catch {
    _ => raise InvalidToken("JWT contains invalid JSON")
  }
}
