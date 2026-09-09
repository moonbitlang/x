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
let integration_key : Bytes = b"0123456789abcdef0123456789abcdef"

///|
struct TypedClaims {
  username : String
  exp : Double
  iss : String
  aud : Array[String]
  roles : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
struct OutboundClaims {
  username : String
  exp : Double
} derive(ToJson)

///|
struct IdentityClaims {
  username : String
} derive(FromJson, Eq, Debug)

///|
struct ConversionProbe {
  username : String
} derive(Eq, Debug)

///|
let conversion_calls : Ref[Int] = Ref(0)

///|
impl @json.FromJson for ConversionProbe with fn from_json(json, path) {
  conversion_calls.val += 1
  if json is { "reject": true, .. } {
    raise @json.JsonDecodeError(
      (
        path.add_key("schema-private-path"),
        "schema-private-message: caller data must not escape the decoder",
      ),
    )
  }
  let identity : IdentityClaims = @json.from_json(json, path~)
  { username: identity.username, }
}

///|
test "public decoding uses the current system clock" {
  let now = @env.now().to_double() / 1000.0
  let valid_claims : Json = { "username": "alice", "exp": now + 3600.0 }
  let valid = @jwt.encode(valid_claims, key=integration_key, algorithm=HS256)
  let decoded : Json = @jwt.decode(valid, key=integration_key, algorithm=HS256)
  assert_eq(decoded, valid_claims)
  let expired_claims : Json = { "username": "alice", "exp": now - 3600.0 }
  let expired = @jwt.encode(
    expired_claims,
    key=integration_key,
    algorithm=HS256,
  )
  try
    (@jwt.decode(expired, key=integration_key, algorithm=HS256) : Json)
  catch {
    error => assert_true(error is @jwt.Expired)
  } noraise {
    _ => fail("expected the current clock to reject the expired token")
  }
}

///|
test "derived claims encode and decode as the application type" {
  let now = @env.now().to_double() / 1000.0
  let claims : TypedClaims = {
    username: "alice",
    exp: now + 3600.0,
    iss: "registry",
    aud: ["web", "api"],
    roles: ["maintainer"],
  }
  let token = @jwt.encode(claims, key=integration_key, algorithm=HS256)
  let decoded : TypedClaims = @jwt.decode(
    token,
    key=integration_key,
    algorithm=HS256,
    issuer="registry",
    audience="api",
  )
  assert_eq(decoded, claims)
}

///|
test "encoding only requires ToJson and decoding only requires FromJson" {
  let now = @env.now().to_double() / 1000.0
  let claims : OutboundClaims = { username: "alice", exp: now + 3600.0, }
  let token = @jwt.encode(claims, key=integration_key, algorithm=HS256)
  let decoded : IdentityClaims = @jwt.decode(
    token,
    key=integration_key,
    algorithm=HS256,
  )
  assert_eq(decoded.username, "alice")
  let raw : Json = @jwt.decode(token, key=integration_key, algorithm=HS256)
  assert_eq(raw, ({ "username": "alice", "exp": claims.exp } : Json))
}

///|
test "partial application claims cannot bypass expiration issuer or audience validation" {
  let now = @env.now().to_double() / 1000.0
  let claims : Json = {
    "username": "alice",
    "exp": now + 3600.0,
    "iss": "registry",
    "aud": "api",
    "extra": true,
  }
  let valid = @jwt.encode(claims, key=integration_key, algorithm=HS256)
  let identity : IdentityClaims = @jwt.decode(
    valid,
    key=integration_key,
    algorithm=HS256,
    issuer="registry",
    audience="api",
  )
  assert_eq(identity.username, "alice")
  let cases : Array[(Json, (@jwt.JwtError) -> Bool)] = [
    (
      {
        "username": "alice",
        "exp": now - 3600.0,
        "iss": "registry",
        "aud": "api",
      },
      error => error is @jwt.Expired,
    ),
    (
      { "username": "alice", "iss": "registry", "aud": "api" },
      error => error is @jwt.InvalidToken(_),
    ),
    (
      { "username": "alice", "exp": now + 3600.0, "iss": "other", "aud": "api" },
      error => error is @jwt.InvalidToken(_),
    ),
    (
      {
        "username": "alice",
        "exp": now + 3600.0,
        "iss": "registry",
        "aud": "other",
      },
      error => error is @jwt.InvalidToken(_),
    ),
  ]
  for (claims, expected) in cases {
    let token = @jwt.encode(claims, key=integration_key, algorithm=HS256)
    try
      (
        @jwt.decode(
          token,
          key=integration_key,
          algorithm=HS256,
          issuer="registry",
          audience="api",
        ) : IdentityClaims)
    catch {
      error => assert_true(expected(error))
    } noraise {
      _ => fail("partial application claims must still satisfy JWT validation")
    }
  }
}

///|
test "missing and mistyped application fields become invalid-token errors" {
  let now = @env.now().to_double() / 1000.0
  let cases : Array[Json] = [
    { "exp": now + 3600.0 },
    { "username": 42, "exp": now + 3600.0 },
  ]
  for claims in cases {
    let token = @jwt.encode(claims, key=integration_key, algorithm=HS256)
    try
      (@jwt.decode(token, key=integration_key, algorithm=HS256) : IdentityClaims)
    catch {
      error =>
        assert_true(error is @jwt.InvalidToken(message) && !message.is_empty())
    } noraise {
      _ => fail("expected the application schema to reject the claims")
    }
  }
}

///|
test "application conversion runs after JWT validation and its diagnostics stay private" {
  let now = @env.now().to_double() / 1000.0
  let not_before = now + 1800.0
  let claims : Json = {
    "username": "alice",
    "exp": now + 3600.0,
    "iss": "registry",
    "aud": "api",
  }
  let valid = @jwt.encode(claims, key=integration_key, algorithm=HS256)
  let forged = @jwt.encode(claims, key=Bytes::make(32, b'x'), algorithm=HS256)
  let rejected : Array[(String, (@jwt.JwtError) -> Bool)] = [
    ("not-a-jwt", error => error is @jwt.InvalidToken(_)),
    (forged, error => error is @jwt.InvalidToken(_)),
  ]
  let invalid_claims : Array[(Json, (@jwt.JwtError) -> Bool)] = [
    (
      { "username": "alice", "iss": "registry", "aud": "api" },
      error => error is @jwt.InvalidToken(_),
    ),
    (
      { "username": "alice", "exp": now + 3600.0, "iss": "other", "aud": "api" },
      error => error is @jwt.InvalidToken(_),
    ),
    (
      {
        "username": "alice",
        "exp": now + 3600.0,
        "iss": "registry",
        "aud": "other",
      },
      error => error is @jwt.InvalidToken(_),
    ),
    (
      {
        "username": "alice",
        "exp": now - 3600.0,
        "iss": "registry",
        "aud": "api",
      },
      error => error is @jwt.Expired,
    ),
    (
      {
        "username": "alice",
        "exp": now + 3600.0,
        "nbf": not_before,
        "iss": "registry",
        "aud": "api",
      },
      error => {
        error is @jwt.NotYetValid(not_before=actual) && actual == not_before
      },
    ),
  ]
  for (claims, expected) in invalid_claims {
    rejected.push(
      (@jwt.encode(claims, key=integration_key, algorithm=HS256), expected),
    )
  }
  for (token, expected) in rejected {
    conversion_calls.val = 0
    try
      (
        @jwt.decode(
          token,
          key=integration_key,
          algorithm=HS256,
          issuer="registry",
          audience="api",
        ) : ConversionProbe)
    catch {
      error => assert_true(expected(error))
    } noraise {
      _ => fail("expected JWT validation to reject the token")
    }
    assert_eq(conversion_calls.val, 0)
  }
  conversion_calls.val = 0
  try
    (@jwt.decode(valid, key=b"short", algorithm=HS256) : ConversionProbe)
  catch {
    error => assert_true(error is @jwt.InvalidArgument(_))
  } noraise {
    _ => fail("expected the decoder to reject a short key")
  }
  assert_eq(conversion_calls.val, 0)
  let decoded : ConversionProbe = @jwt.decode(
    valid,
    key=integration_key,
    algorithm=HS256,
    issuer="registry",
    audience="api",
  )
  assert_eq(decoded.username, "alice")
  assert_eq(conversion_calls.val, 1)
  let schema_claims : Json = {
    "username": "alice",
    "exp": now + 3600.0,
    "iss": "registry",
    "aud": "api",
    "reject": true,
  }
  let rejected_by_schema = @jwt.encode(
    schema_claims,
    key=integration_key,
    algorithm=HS256,
  )
  conversion_calls.val = 0
  try
    (
      @jwt.decode(
        rejected_by_schema,
        key=integration_key,
        algorithm=HS256,
        issuer="registry",
        audience="api",
      ) : ConversionProbe)
  catch {
    error => {
      guard error is @jwt.InvalidToken(message) else {
        fail("expected schema failure to become an invalid-token error")
      }
      assert_false(message.is_empty())
      assert_false(message.contains("schema-private-path"))
      assert_false(message.contains("schema-private-message"))
      assert_false(message.contains("caller data must not escape the decoder"))
    }
  } noraise {
    _ => fail("expected the custom application decoder to reject the claims")
  }
  assert_eq(conversion_calls.val, 1)
}
