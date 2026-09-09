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
test "from_hex" {
  let hex = "13cb501c-1234-5678-9034-abcdef937e20"
  inspect(@uuid.from_hex(hex), content=hex)
  debug_inspect(
    @uuid.from_hex(hex),
    content="UUID(\"13cb501c-1234-5678-9034-abcdef937e20\")",
  )
  inspect(
    @uuid.from_hex("12345678-1234-1234-1234-ABCDEF098765"),
    content="12345678-1234-1234-1234-abcdef098765",
  )
  @test.assert_raise(() => @uuid.from_hex("13cb"))
  @test.assert_raise(() => @uuid.from_hex("13cb501c-99a8-c889-3234"))
}

///|
test "ops" {
  let hex = "72212911-64d1-c441-e87d-de89b955ea34"
  let u1 = @uuid.from_hex(hex)
  let u1x = @uuid.from_hex(hex)
  let u2 = @uuid.from_hex("8e325b13-2bf1-d7f6-d2b0-c85a371c1878")
  inspect(u1 == u1x, content="true")
  inspect(Compare::compare(u1, u2), content="1")
  inspect(Compare::compare(u2, u1), content="-1")
  inspect(Compare::compare(u1, u1x), content="0")
  assert_eq(u1, u1x)
}

///|
test "json_roundtrip" {
  let hex = "13cb501c-1234-5678-9034-abcdef937e20"
  let uuid = @uuid.from_hex(hex)
  debug_inspect(
    ToJson::to_json(uuid),
    content="String(\"13cb501c-1234-5678-9034-abcdef937e20\")",
  )
  let back : @uuid.UUID = @json.from_json(ToJson::to_json(uuid))
  inspect(back, content=hex)
}

///|
test "json_errors" {
  try {
    let _ : @uuid.UUID = @json.from_json(Json::number(1))
    fail("expected JsonDecodeError")
  } catch {
    @json.JsonDecodeError((_, msg)) =>
      inspect(msg, content="UUID::from_json: expected string representation")
    _ => fail("unexpected error")
  }
  try {
    let _ : @uuid.UUID = @json.from_json(
      Json::string("13cb501c-99a8-c889-3234"),
    )
    fail("expected JsonDecodeError")
  } catch {
    @json.JsonDecodeError((_, msg)) =>
      inspect(
        msg,
        content="UUID::from_json: invalid uuid string - 13cb501c-99a8-c889-3234",
      )
    _ => fail("unexpected error")
  }
}
