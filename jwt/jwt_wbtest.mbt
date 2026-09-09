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
// Fixed test key, used as 32 raw UTF-8 bytes.
let test_key : Bytes = b"0123456789abcdef0123456789abcdef"

///|
// Fixtures verified with python-jose 3.4.0, test_key and now=1000.
// Claims: {"test":"basic","exp":1001}
const BasicFixture : String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZXN0IjoiYmFzaWMiLCJleHAiOjEwMDF9.2shPeSExv7oZ7gn1Yp5shg1RCf2mwH56ydmf7aSYids"

///|
// Claims: {"test":"null","value":null,"exp":1001}
const NullFixture : String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZXN0IjoibnVsbCIsInZhbHVlIjpudWxsLCJleHAiOjEwMDF9.WqhL-u0q3ncCMq6LK9_lkxeLhcgaN5MBpsVCWGt1Aug"

///|
// Claims: {"test":"unicode","value":"你好🌙","exp":1001}
const UnicodeFixture : String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZXN0IjoidW5pY29kZSIsInZhbHVlIjoiXHU0ZjYwXHU1OTdkXHVkODNjXHVkZjE5IiwiZXhwIjoxMDAxfQ.xgqKpNLxwxy0RCTej6z27-tTLxy3ja1WYOnBET3Y4Ek"

///|
// Claims: {"exp":1001,"test":"basic"}, with CRLF and spaces in the JSON.
const WhitespaceFixture : String = "ew0KICJ0eXAiOiJKV1QiLCAiYWxnIjoiSFMyNTYiDQp9.ew0KICJleHAiOjEwMDEsICJ0ZXN0IjoiYmFzaWMiDQp9.v2ky1Oupx8WXJ-Hme67gM4N7DV1S6U2GUVpCMwCvDIs"

///|
fn base64url(bytes : Bytes) -> String {
  @base64.encode(bytes, padding=false)
  .replace_all(old="+", new="-")
  .replace_all(old="/", new="_")
}

///|
// Sign arbitrary encoded segments so invalid JSON/encoding can be tested with
// a valid MAC, independently of encode()'s validation and serialization.
fn signed_segments(header : String, payload : String) -> String {
  let input = "\{header}.\{payload}"
  let signature = @crypto.hmac(
    @crypto.SHA256::new(),
    test_key,
    @utf8.encode(input),
  )
  "\{input}.\{base64url(Bytes::from_array(signature[:]))}"
}

///|
fn raw_token(header : String, payload : String) -> String {
  signed_segments(
    base64url(@utf8.encode(header)),
    base64url(@utf8.encode(payload)),
  )
}

///|
fn expect_decode_error(
  token : String,
  expected? : (JwtError) -> Bool,
  key? : Bytes = test_key,
  now? : Double = 1000.0,
  leeway? : Int = 0,
  require_exp? : Bool = true,
  issuer? : String,
  audience? : String,
) -> Unit raise {
  try
    (
      decode_at(
        token,
        key~,
        algorithm=HS256,
        now~,
        leeway~,
        require_exp~,
        issuer?,
        audience?,
      ) : Json)
  catch {
    error =>
      if expected is Some(check) {
        assert_true(check(error), msg="unexpected JWT error category")
      } else {
        assert_true(error is InvalidToken(message) && !message.is_empty())
      }
  } noraise {
    _ => fail("expected JWT decoding to fail")
  }
}

///|
fn expect_encode_error(claims : Json) -> Unit raise {
  try encode(claims, key=test_key, algorithm=HS256) catch {
    error =>
      assert_true(error is InvalidArgument(message) && !message.is_empty())
  } noraise {
    _ => fail("expected JWT encoding to fail")
  }
}

///|
test "Python fixtures preserve custom claims and null values" {
  json_inspect(
    (decode_at(BasicFixture, key=test_key, algorithm=HS256, now=1000) : Json),
    content={ "test": "basic", "exp": 1001 },
  )
  json_inspect(
    (decode_at(NullFixture, key=test_key, algorithm=HS256, now=1000) : Json),
    content={ "test": "null", "value": null, "exp": 1001 },
  )
}

///|
test "Python JSON escapes and original whitespace are authenticated without reserialization" {
  json_inspect(
    (decode_at(UnicodeFixture, key=test_key, algorithm=HS256, now=1000) : Json),
    content={ "test": "unicode", "value": "你好🌙", "exp": 1001 },
  )
  json_inspect(
    (
      decode_at(WhitespaceFixture, key=test_key, algorithm=HS256, now=1000) :
      Json),
    content={ "exp": 1001, "test": "basic" },
  )
}

///|
test "HS256 encoding reproduces the independently verified Python fixture" {
  let claims : Json = { "test": "basic", "exp": 1001 }
  assert_eq(encode(claims, key=test_key, algorithm=HS256), BasicFixture)
  // Encode does not mutate, insert, or normalize application claims.
  json_inspect(claims, content={ "test": "basic", "exp": 1001 })
}

///|
test "RFC 7515 Appendix A.1 HMAC SHA-256 example decodes" {
  // Public test vector: https://www.rfc-editor.org/rfc/rfc7515#appendix-A.1
  let key = @base64.decode(
    "AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ+EstJQLr/T+1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow",
  )
  let token = "eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  json_inspect(
    (
      decode_at(token, key~, algorithm=HS256, now=1300819379, issuer="joe") :
      Json),
    content={
      "iss": "joe",
      "exp": 1300819380,
      "http://example.com/is_root": true,
    },
  )
}

///|
test "raw keys at the minimum length and above the HMAC block size roundtrip" {
  let claims : Json = { "exp": 1001, "data": [null, true, "🌙"] }
  for length in [32, 33, 64, 65, 128] {
    let key = Bytes::make(length, b'\xAB')
    let token = encode(claims, key~, algorithm=HS256)
    assert_eq(
      (decode_at(token, key~, algorithm=HS256, now=1000) : Json),
      claims,
    )
  }
  for length in [0, 1, 16, 31] {
    let key = Bytes::make(length, b'a')
    try encode(claims, key~, algorithm=HS256) catch {
      error =>
        assert_true(error is InvalidArgument(message) && !message.is_empty())
    } noraise {
      _ => fail("expected a short signing key to be rejected")
    }
    expect_decode_error(BasicFixture, key~, expected=error => {
      error is InvalidArgument(message) && !message.is_empty()
    })
  }
}

///|
test "a different key and every modified signature byte are rejected" {
  expect_decode_error(BasicFixture, key=Bytes::make(32, b'x'))
  guard BasicFixture.split(".").to_array() is [header, payload, signature] else {
    fail("fixture must have three segments")
  }
  let decoded = @base64.decode(
    signature
    .to_owned()
    .replace_all(old="-", new="+")
    .replace_all(old="_", new="/"),
  )
  for index in 0..<32 {
    let changed = decoded.to_fixedarray()
    changed[index] = (changed[index].to_int() ^ 1).to_byte()
    expect_decode_error(
      "\{header}.\{payload}.\{base64url(Bytes::from_array(changed[:]))}",
    )
  }
  let changed_payload = base64url(b"{\"test\":\"changed\",\"exp\":1001}")
  expect_decode_error("\{header}.\{changed_payload}.\{signature}")
}

///|
test "token algorithm never overrides the caller's HS256 selection" {
  for algorithm in ["none", "HS384", "HS512", "RS256", "hs256", "unknown"] {
    let token = raw_token("{\"alg\":\"\{algorithm}\"}", "{\"exp\":1001}")
    expect_decode_error(token)
  }
}

///|
test "JWT header structure and optional media type are validated" {
  for header in ["{}", "[]", "null", "{\"alg\":null}", "{\"alg\":256}"] {
    expect_decode_error(raw_token(header, "{\"exp\":1001}"))
  }
  for typ in ["null", "true", "123", "[]", "\"JWS\""] {
    expect_decode_error(
      raw_token("{\"alg\":\"HS256\",\"typ\":\{typ}}", "{\"exp\":1001}"),
    )
  }
  for
    header in [
      "{\"alg\":\"HS256\"}", "{\"alg\":\"HS256\",\"typ\":\"jwt\"}", "{\"alg\":\"HS256\",\"typ\":\"JwT\",\"kid\":\"unused-test-key\"}",
    ] {
    json_inspect(
      (
        decode_at(
          raw_token(header, "{\"exp\":1001}"),
          key=test_key,
          algorithm=HS256,
          now=1000,
        ) : Json),
      content={ "exp": 1001 },
    )
  }
}

///|
test "explicit b64 true uses ordinary payload encoding" {
  for
    header in [
      "{\"alg\":\"HS256\",\"b64\":true}", "{\"alg\":\"HS256\",\"b64\":true,\"crit\":[\"b64\"]}",
    ] {
    let token = raw_token(header, "{\"exp\":1001,\"sub\":\"alice\"}")
    json_inspect(
      (decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json),
      content={ "exp": 1001, "sub": "alice" },
    )
    expect_decode_error(token, key=b"1123456789abcdef0123456789abcdef")
  }
  expect_decode_error(
    raw_token(
      "{\"alg\":\"HS256\",\"b64\":true,\"crit\":[\"example\"],\"example\":true}",
      "{\"exp\":1001}",
    ),
  )
}

///|
test "unsupported critical extensions and invalid b64 values are rejected" {
  for
    (name, value) in [
      ("crit", "[]"),
      ("crit", "[\"example\"]"),
      ("crit", "null"),
      ("b64", "false"),
      ("b64", "null"),
      ("b64", "0"),
      ("b64", "\"true\""),
      ("b64", "[]"),
      ("b64", "{}"),
    ] {
    expect_decode_error(
      raw_token("{\"alg\":\"HS256\",\"\{name}\":\{value}}", "{\"exp\":1001}"),
    )
  }
  for
    crit in [
      "[]", "null", "\"b64\"", "[\"b64\",\"b64\"]", "[\"b64\",null]", "[\"b64\",\"example\"]",
    ] {
    expect_decode_error(
      raw_token(
        "{\"alg\":\"HS256\",\"b64\":true,\"crit\":\{crit}}",
        "{\"exp\":1001}",
      ),
    )
  }
  for b64 in ["false", "null", "\"true\""] {
    expect_decode_error(
      raw_token(
        "{\"alg\":\"HS256\",\"b64\":\{b64},\"crit\":[\"b64\"]}",
        "{\"exp\":1001}",
      ),
    )
  }
  expect_decode_error(
    raw_token("{\"alg\":\"HS256\",\"crit\":[\"b64\"]}", "{\"exp\":1001}"),
  )
}

///|
test "compact token requires three nonempty unpadded Base64URL segments" {
  let header = base64url(b"{\"alg\":\"HS256\"}")
  let payload = base64url(b"{\"exp\":1001}")
  for token in ["", ".", "..", "a.b", "a.b.c.d", ".a.b", "a..b", "a.b."] {
    expect_decode_error(token)
  }
  for
    invalid in ["=", "A", "AA=", "AA==", "AA+", "AA/", "AA ", "AA\n", "AA🌙"] {
    expect_decode_error(signed_segments(invalid, payload))
    expect_decode_error(signed_segments(header, invalid))
  }
  let valid = raw_token("{\"alg\":\"HS256\"}", "{\"exp\":1001}")
  guard valid.split(".").to_array() is [_, _, signature] else {
    fail("test token must have three segments")
  }
  for
    invalid_signature in [
      "",
      "A",
      "\{signature}=",
      "\{signature} ",
      "+\{signature}",
      "/\{signature}",
    ] {
    expect_decode_error("\{header}.\{payload}.\{invalid_signature}")
  }
}

///|
test "signature length is checked separately from valid Base64URL syntax" {
  let header = base64url(b"{\"alg\":\"HS256\"}")
  let payload = base64url(b"{\"exp\":1001}")
  for length in [1, 16, 31, 33, 64] {
    let signature = base64url(Bytes::make(length, b'\x00'))
    expect_decode_error("\{header}.\{payload}.\{signature}")
  }
}

///|
test "noncanonical Base64URL trailing bits are rejected" {
  // e30 is {}, while e31 has the same decoded bytes with nonzero unused bits.
  expect_decode_error(signed_segments("e31", "e30"))
  let header = base64url(b"{\"alg\":\"HS256\"}")
  expect_decode_error(signed_segments(header, "e31"))
  // 32 zero bytes encode to 43 As; changing the last sextet to B changes only
  // its two unused bits, which must still be rejected before MAC comparison.
  expect_decode_error("\{header}.e30.\{"A".repeat(42)}B")
}

///|
test "authenticated malformed JSON and invalid UTF-8 fail without exposing claims" {
  let header = base64url(b"{\"alg\":\"HS256\"}")
  for
    invalid in [
      "{", "{\"exp\":}", "{\"exp\":1001} trailing", "{\"x\":\"\\uZZZZ\"}",
    ] {
    expect_decode_error(raw_token(invalid, "{\"exp\":1001}"))
    expect_decode_error(raw_token("{\"alg\":\"HS256\"}", invalid))
  }
  for bytes in [b"\xFF", b"\xC0\xAF", b"\xED\xA0\x80", b"\xEF\xBB\xBF{}"] {
    let invalid = base64url(bytes)
    expect_decode_error(signed_segments(invalid, "e30"))
    expect_decode_error(signed_segments(header, invalid))
  }
  for payload in ["null", "true", "1", "\"claims\"", "[]"] {
    expect_decode_error(raw_token("{\"alg\":\"HS256\"}", payload))
  }
}

///|
test "duplicate JSON members consistently use their final value" {
  let accepted = raw_token(
    "{\"alg\":\"none\",\"alg\":\"HS256\"}", "{\"exp\":1,\"exp\":1001,\"username\":\"old\",\"username\":\"new\"}",
  )
  json_inspect(
    (decode_at(accepted, key=test_key, algorithm=HS256, now=1000) : Json),
    content={ "exp": 1001, "username": "new" },
  )
  expect_decode_error(
    raw_token("{\"alg\":\"HS256\",\"alg\":\"none\"}", "{\"exp\":1001}"),
  )
  expect_decode_error(
    raw_token("{\"alg\":\"HS256\"}", "{\"exp\":1001,\"exp\":1}"),
    expected=error => error is Expired,
  )
}

///|
test "expiration is required by default and checked even when it is optional" {
  let no_exp = encode(
    ({ "username": "alice" } : Json),
    key=test_key,
    algorithm=HS256,
  )
  expect_decode_error(no_exp)
  json_inspect(
    (
      decode_at(
        no_exp,
        key=test_key,
        algorithm=HS256,
        now=1000,
        require_exp=false,
      ) : Json),
    content={ "username": "alice" },
  )
  let expired = encode(({ "exp": 999 } : Json), key=test_key, algorithm=HS256)
  expect_decode_error(expired, require_exp=false, expected=error => {
    error is Expired
  })
  expect_decode_error(
    raw_token("{\"alg\":\"HS256\"}", "{\"exp\":null}"),
    require_exp=false,
  )
}

///|
test "expiration boundary and fractional NumericDates retain precision" {
  for expiration in [999.5, 1000.0] {
    let token = encode(
      ({ "exp": expiration } : Json),
      key=test_key,
      algorithm=HS256,
    )
    expect_decode_error(token, expected=error => error is Expired)
  }
  for expiration in [1000.25, 1001.0] {
    let claims : Json = { "exp": expiration }
    let token = encode(claims, key=test_key, algorithm=HS256)
    assert_eq(
      (decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json),
      claims,
    )
  }
  let token = encode(({ "exp": 1000 } : Json), key=test_key, algorithm=HS256)
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=1000, leeway=1) : Json),
    Json::object({ "exp": Json::number(1000) }),
  )
  expect_decode_error(token, now=1001, leeway=1, expected=error => {
    error is Expired
  })
}

///|
test "not-before boundary allows equality and applies positive clock tolerance" {
  for nbf in [999.5, 1000.0] {
    let claims : Json = { "exp": 1010, "nbf": nbf }
    let token = encode(claims, key=test_key, algorithm=HS256)
    assert_eq(
      (decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json),
      claims,
    )
  }
  for nbf in [1000.25, 1001.0] {
    let claims : Json = { "exp": 1010, "nbf": nbf }
    let token = encode(claims, key=test_key, algorithm=HS256)
    expect_decode_error(token, expected=error => {
      error is NotYetValid(not_before=actual) && actual == nbf
    })
    assert_eq(
      (
        decode_at(token, key=test_key, algorithm=HS256, now=1000, leeway=1) :
        Json),
      claims,
    )
  }
  let future_iat : Json = { "exp": 1010, "iat": 2000.5 }
  let token = encode(future_iat, key=test_key, algorithm=HS256)
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json),
    future_iat,
  )
}

///|
test "fractional current time observes expiration without truncating to whole seconds" {
  let claims : Json = { "exp": 1000.5 }
  let token = encode(claims, key=test_key, algorithm=HS256)
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=1000.499) : Json),
    claims,
  )
  for now in [1000.5, 1000.75] {
    expect_decode_error(token, now~, expected=error => error is Expired)
  }
  assert_eq(
    (
      decode_at(token, key=test_key, algorithm=HS256, now=1001.499, leeway=1) :
      Json),
    claims,
  )
  for now in [1001.5, 1001.75] {
    expect_decode_error(token, now~, leeway=1, expected=error => {
      error is Expired
    })
  }
}

///|
test "fractional current time and leeway preserve the original not-before date" {
  let claims : Json = { "exp": 1010, "nbf": 1000.5 }
  let token = encode(claims, key=test_key, algorithm=HS256)
  expect_decode_error(token, now=1000.25, expected=error => {
    error is NotYetValid(not_before=actual) && actual == 1000.5
  })
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=1000.5) : Json),
    claims,
  )
  expect_decode_error(token, now=999.25, leeway=1, expected=error => {
    error is NotYetValid(not_before=actual) && actual == 1000.5
  })
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=999.5, leeway=1) : Json),
    claims,
  )
}

///|
test "fractional negative Unix times retain expiration and not-before ordering" {
  let claims : Json = { "exp": -0.25, "nbf": -1.5 }
  let token = encode(claims, key=test_key, algorithm=HS256)
  for now in [-1.5, -1.0, -0.5] {
    assert_eq(
      (decode_at(token, key=test_key, algorithm=HS256, now~) : Json),
      claims,
    )
  }
  expect_decode_error(token, now=-0.25, expected=error => error is Expired)
  expect_decode_error(token, now=-1.75, expected=error => {
    error is NotYetValid(not_before=actual) && actual == -1.5
  })
}

///|
test "NumericDates reject coercions and nonfinite values on encode and decode" {
  for name in ["exp", "nbf", "iat"] {
    for
      invalid in [
        "null", "true", "false", "\"1001\"", "[]", "{}", "1e999", "-1e999",
      ] {
      let payload = "{\"exp\":1001,\"\{name}\":\{invalid}}"
      expect_encode_error(@json.parse(payload))
      expect_decode_error(raw_token("{\"alg\":\"HS256\"}", payload))
    }
    for number in [@double.infinity, @double.neg_infinity, @double.not_a_number] {
      let values : Map[String, Json] = { "exp": Json::number(1001) }
      values[name] = Json::number(number)
      expect_encode_error(Json::object(values))
    }
  }
}

///|
test "finite NumericDates can exceed the exact integer range" {
  for date in [9007199254740992.0, 1.0e200] {
    let claims : Json = { "exp": date, "nbf": -date, "iat": date }
    let token = encode(claims, key=test_key, algorithm=HS256)
    let decoded : Json = decode_at(
      token,
      key=test_key,
      algorithm=HS256,
      now=1000,
    )
    assert_eq(decoded, claims)
    let expired = encode(
      ({ "exp": -date } : Json),
      key=test_key,
      algorithm=HS256,
    )
    expect_decode_error(expired, expected=error => error is Expired)
    let future = encode(
      ({ "exp": date, "nbf": date } : Json),
      key=test_key,
      algorithm=HS256,
    )
    expect_decode_error(future, expected=error => {
      error is NotYetValid(not_before=actual) && actual == date
    })
  }
}

///|
test "invalid verifier arguments take precedence over malformed credentials" {
  for token in ["", "not-a-jwt", "e30.e30.AA"] {
    expect_decode_error(token, key=b"short", expected=error => {
      error is InvalidArgument(message) && !message.is_empty()
    })
    expect_decode_error(token, leeway=-1, expected=error => {
      error is InvalidArgument(message) && !message.is_empty()
    })
  }
}

///|
test "forged signatures never produce recoverable expiration or not-before errors" {
  for
    claims in [
      Json::object({ "exp": Json::number(999) }),
      Json::object({ "exp": Json::number(1010), "nbf": Json::number(1001) }),
      Json::object({ "exp": Json::number(999), "nbf": Json::number(1001) }),
    ] {
    let token = encode(claims, key=Bytes::make(32, b'x'), algorithm=HS256)
    expect_decode_error(token)
  }
}

///|
test "issuer and audience mismatches take precedence over recoverable time errors" {
  for (expiration, not_before) in [(999.0, 0.0), (1010.0, 1001.25)] {
    let wrong_issuer = encode(
      ({ "exp": expiration, "nbf": not_before, "iss": "unexpected" } : Json),
      key=test_key,
      algorithm=HS256,
    )
    expect_decode_error(wrong_issuer, issuer="expected")
    let wrong_audience = encode(
      ({ "exp": expiration, "nbf": not_before, "aud": "unexpected" } : Json),
      key=test_key,
      algorithm=HS256,
    )
    expect_decode_error(wrong_audience, audience="expected")
    // An unconfigured verifier cannot accept an audience-specific token,
    // even when retrying later or renewing the token would address its dates.
    expect_decode_error(wrong_audience)
  }
}

///|
test "issuer and audience policy requires configured claims and exact matches" {
  let absent = encode(({ "exp": 1001 } : Json), key=test_key, algorithm=HS256)
  expect_decode_error(absent, issuer="issuer")
  expect_decode_error(absent, audience="api")
  let issued = encode(
    ({ "exp": 1001, "iss": "Issuer" } : Json),
    key=test_key,
    algorithm=HS256,
  )
  ignore((decode_at(issued, key=test_key, algorithm=HS256, now=1000) : Json))
  ignore(
    (
      decode_at(
        issued,
        key=test_key,
        algorithm=HS256,
        now=1000,
        issuer="Issuer",
      ) : Json),
  )
  expect_decode_error(issued, issuer="issuer")
  for
    audiences in [
      Json::string("api"),
      Json::array([Json::string("web"), Json::string("api")]),
    ] {
    let claims : Json = { "exp": 1001, "aud": audiences }
    let token = encode(claims, key=test_key, algorithm=HS256)
    assert_eq(
      (
        decode_at(
          token,
          key=test_key,
          algorithm=HS256,
          now=1000,
          audience="api",
        ) : Json),
      claims,
    )
    expect_decode_error(token)
    expect_decode_error(token, audience="API")
  }
  let empty_aud = encode(
    ({ "exp": 1001, "aud": [] } : Json),
    key=test_key,
    algorithm=HS256,
  )
  expect_decode_error(empty_aud, audience="api")
}

///|
test "reserved textual claims and audience arrays reject incorrect types" {
  for name in ["iss", "sub", "jti"] {
    for invalid in ["null", "123", "false", "[]", "{}"] {
      let payload = "{\"exp\":1001,\"\{name}\":\{invalid}}"
      expect_encode_error(@json.parse(payload))
      expect_decode_error(raw_token("{\"alg\":\"HS256\"}", payload))
    }
  }
  for invalid in ["null", "123", "true", "{}", "[\"api\",null]", "[1]"] {
    let payload = "{\"exp\":1001,\"aud\":\{invalid}}"
    expect_encode_error(@json.parse(payload))
    expect_decode_error(
      raw_token("{\"alg\":\"HS256\"}", payload),
      audience="api",
    )
  }
  for
    invalid in [
      Json::null(),
      Json::number(1),
      Json::array([]),
      Json::string("claims"),
    ] {
    expect_encode_error(invalid)
  }
}

///|
test "unrelated application claims are returned without imposing account rules" {
  let claims : Json = {
    "exp": 1001,
    "username": null,
    "roles": ["maintainer"],
    "metadata": { "nested": [true, null, 42] },
    "at_hash": "application-defined",
  }
  let token = encode(claims, key=test_key, algorithm=HS256)
  assert_eq(
    (decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json),
    claims,
  )
}

///|
test "compact token length limit includes header payload separators and signature" {
  // With this fixed 20-character header, 49,103 payload bytes encode to 65,471
  // characters, making the entire token exactly 65,536 ASCII bytes.
  let header = base64url(b"{\"alg\":\"HS256\"}")
  let prefix = "{\"exp\":1001,\"data\":\""
  let suffix = "\"}"
  let payload = prefix +
    "a".repeat(49103 - prefix.length() - suffix.length()) +
    suffix
  let token = signed_segments(header, base64url(@utf8.encode(payload)))
  assert_eq(token.length(), 65536)
  ignore((decode_at(token, key=test_key, algorithm=HS256, now=1000) : Json))
  expect_decode_error(token + "A")
  let oversized : Json = { "exp": 1001, "data": "a".repeat(50000) }
  expect_encode_error(oversized)
}

///|
test "JSON nesting limit applies to signed headers claims and encoding input" {
  let allowed_payload = "{\"exp\":1001,\"data\":" +
    "[".repeat(64) +
    "0" +
    "]".repeat(64) +
    "}"
  let allowed = raw_token("{\"alg\":\"HS256\"}", allowed_payload)
  ignore((decode_at(allowed, key=test_key, algorithm=HS256, now=1000) : Json))
  let deep_payload = "{\"exp\":1001,\"data\":" +
    "[".repeat(1024) +
    "0" +
    "]".repeat(1024) +
    "}"
  expect_decode_error(raw_token("{\"alg\":\"HS256\"}", deep_payload))
  let deep_header = "{\"alg\":\"HS256\",\"data\":" +
    "[".repeat(1024) +
    "0" +
    "]".repeat(1024) +
    "}"
  expect_decode_error(raw_token(deep_header, "{\"exp\":1001}"))
  let mut nested = Json::number(0)
  for _ in 0..<1024 {
    nested = Json::array([nested])
  }
  expect_encode_error({ "exp": 1001, "data": nested })
}

///|
test "unpaired UTF-16 code units return errors instead of reaching native UTF-8 encoding" {
  let malformed = [
    String::from_array([(0xD800).unsafe_to_char()]),
    String::from_array([(0xDC00).unsafe_to_char()]),
    String::from_array([(0xD800).unsafe_to_char(), 'A']),
    String::from_array(['A', (0xDC00).unsafe_to_char()]),
  ]
  for value in malformed {
    for
      token in [
        value,
        value + ".e30.AA",
        "e30." + value + ".AA",
        "e30.e30." + value,
      ] {
      expect_decode_error(token)
    }
    expect_encode_error({ "exp": 1001, "data": value })
  }
}

///|
test "encode validates the serialized NumericDate representation" {
  for repr in ["null", "true", "\"1001\"", "1e999"] {
    let claims : Json = { "exp": Json::number(1001.0, repr~) }
    expect_encode_error(claims)
  }
  let claims : Json = { "exp": Json::number(1001.0, repr="invalid-json") }
  expect_encode_error(claims)
  let claims : Json = { "exp": Json::number(@double.infinity, repr="1001") }
  let token = encode(claims, key=test_key, algorithm=HS256)
  let decoded : Json = decode_at(token, key=test_key, algorithm=HS256, now=1000)
  json_inspect(decoded, content={ "exp": 1001 })
}
