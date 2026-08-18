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
test "op_add" {
  // 1/2 + 1/3 = 5/6
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 3L)
  let c = a + b
  assert_eq(c.numerator, 5L)
  assert_eq(c.denominator, 6L)

  // 1/2 + 1/2 = 1
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 2L)
  let c = a + b
  assert_eq(c.numerator, 1L)
  assert_eq(c.denominator, 1L)

  // 1/2 + 1/6 = 2/3
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 6L)
  let c = a + b
  assert_eq(c.numerator, 2L)

  // -1/2 + 1/2 = 0
  let a = new_unchecked(-1L, 2L)
  let b = new_unchecked(1L, 2L)
  let c = a + b
  assert_eq(c.numerator, 0L)

  // -1/2 + -1/2 = -1
  let a = new_unchecked(-1L, 2L)
  let b = new_unchecked(-1L, 2L)
  let c = a + b
  assert_eq(c.numerator, -1L)
  assert_eq(c.denominator, 1L)
}

///|
test "op_sub" {
  // 1/2 - 1/3 = 1/6
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 3L)
  let c = a - b
  assert_eq(c.numerator, 1L)
  assert_eq(c.denominator, 6L)

  // 1/2 - 1/2 = 0
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 2L)
  let c = a - b
  assert_eq(c.numerator, 0L)

  // 1/2 - 1/6 = 1/3
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 6L)
  let c = a - b
  assert_eq(c.numerator, 1L)
  assert_eq(c.denominator, 3L)

  // -1/2 - 1/2 = -1
  let a = new_unchecked(-1L, 2L)
  let b = new_unchecked(1L, 2L)
  let c = a - b
  assert_eq(c.numerator, -1L)
  assert_eq(c.denominator, 1L)

  // -1/2 - -1/2 = 0
  let a = new_unchecked(-1L, 2L)
  let b = new_unchecked(-1L, 2L)
  let c = a - b
  assert_eq(c.numerator, 0L)
}

///|
test "op_mul" {
  // 1/2 * 2/3 = 1/3
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(2L, 3L)
  let c = a * b
  assert_eq(c.numerator, 1L)
  assert_eq(c.denominator, 3L)

  // -4/3 * 3/4 = -1
  let a = new_unchecked(-4L, 3L)
  let b = new_unchecked(3L, 4L)
  let c = a * b
  assert_eq(c.numerator, -1L)
  assert_eq(c.denominator, 1L)

  // 1024/42 * 0 = 0
  let a = new_unchecked(1024L, 42L)
  let b = new_unchecked(0L, 1L)
  let c = a * b
  assert_eq(c.numerator, 0L)
  assert_eq(c.denominator, 1L)
}

///|
test "op_div" {
  // 1/2 / 2/3 = 3/4
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(2L, 3L)
  let c = a / b
  assert_eq(c.numerator, 3L)
  assert_eq(c.denominator, 4L)

  // 1/2 / -2/3 = -3/4
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(-2L, 3L)
  let c = a / b
  assert_eq(c.numerator, -3L)
  assert_eq(c.denominator, 4L)

  // 0 / 1 = 0
  let a = new_unchecked(0L, 1L)
  let b = new_unchecked(1L, 1L)
  let c = a / b
  assert_eq(c.numerator, 0L)
  assert_eq(c.denominator, 1L)
}

///|
test "reciprocal" {
  // 1/2 -> 2/1
  let a = new_unchecked(1L, 2L)
  let b = a.reciprocal()
  assert_eq(b.numerator, 2L)
  assert_eq(b.denominator, 1L)

  // -1/2 -> -2/1
  let a = new_unchecked(-1L, 2L)
  let b = a.reciprocal()
  assert_eq(b.numerator, -2L)
  assert_eq(b.denominator, 1L)
}

///|
test "neg" {
  // 1/2 -> -1/2
  let a = new_unchecked(1L, 2L)
  let b = -a
  assert_eq(b.numerator, -1L)
  assert_eq(b.denominator, 2L)

  // -1/2 -> 1/2
  let a = new_unchecked(-1L, 2L)
  let b = -a
  assert_eq(b.numerator, 1L)
  assert_eq(b.denominator, 2L)
}

///|
test "abs" {
  // 1/2 -> 1/2
  let a = new_unchecked(1L, 2L)
  let b = a.abs()
  assert_eq(b.numerator, 1L)
  assert_eq(b.denominator, 2L)

  // -1/2 -> 1/2
  let a = new_unchecked(-1L, 2L)
  let b = a.abs()
  assert_eq(b.numerator, 1L)
  assert_eq(b.denominator, 2L)
}

///|
test "to_double" {
  // 1/2 -> 0.5
  let a = new_unchecked(1L, 2L)
  let b = a.to_double()
  assert_eq(b, 0.5)

  // -1/2 -> -0.5
  let a = new_unchecked(-1L, 2L)
  let b = a.to_double()
  assert_eq(b, -0.5)
}

///|
test "ceil" {
  // 1/2 -> 1
  let a = new_unchecked(1L, 2L)
  let b = a.ceil()
  assert_eq(b, 1L)

  // -1/2 -> 0
  let a = new_unchecked(-1L, 2L)
  let b = a.ceil()
  assert_eq(b, 0L)

  // -2/2 -> -1
  let a = new_unchecked(-2L, 2L)
  let b = a.ceil()
  assert_eq(b, -1L)

  // 2/2 -> 1
  let a = new_unchecked(2L, 2L)
  let b = a.ceil()
  assert_eq(b, 1L)
}

///|
test "floor" {
  // 1/2 -> 0
  let a = new_unchecked(1L, 2L)
  let b = a.floor()
  assert_eq(b, 0L)

  // -1/2 -> -1
  let a = new_unchecked(-1L, 2L)
  let b = a.floor()
  assert_eq(b, -1L)

  // -2/2 -> -1
  let a = new_unchecked(-2L, 2L)
  let b = a.floor()
  assert_eq(b, -1L)

  // 2/2 -> 1
  let a = new_unchecked(2L, 2L)
  let b = a.floor()
  assert_eq(b, 1L)
}

///|
test "trunc" {
  // 1/2 -> 0
  let a = new_unchecked(1L, 2L)
  let b = a.trunc()
  assert_eq(b, 0L)

  // -1/2 -> 0
  let a = new_unchecked(-1L, 2L)
  let b = a.trunc()
  assert_eq(b, 0L)
}

///|
test "fract" {
  // 1/2 -> 1/2
  let a = new_unchecked(1L, 2L)
  let b = a.fract()
  assert_eq(b.numerator, 1L)
  assert_eq(b.denominator, 2L)

  // -1/2 -> -1/2
  let a = new_unchecked(-1L, 2L)
  let b = a.fract()
  assert_eq(b.numerator, -1L)
  assert_eq(b.denominator, 2L)

  // 3/2 -> 1/2
  let a = new_unchecked(3L, 2L)
  let b = a.fract()
  assert_eq(b.numerator, 1L)
  assert_eq(b.denominator, 2L)

  // -3/2 -> -1/2
  let a = new_unchecked(-3L, 2L)
  let b = a.fract()
  assert_eq(b.numerator, -1L)
  assert_eq(b.denominator, 2L)
}

///|
test "to_string" {
  // 1/2 -> "1/2"
  let a = new_unchecked(1L, 2L)
  let b = Show::to_string(a)
  assert_eq(b, "1/2")

  // 4/4 -> "1"
  let a = new_unchecked(4L, 4L)
  let b = Show::to_string(a)
  assert_eq(b, "1")

  // 0/1 -> "0"
  let a = new_unchecked(0L, 1L)
  let b = Show::to_string(a)
  assert_eq(b, "0")
}

///|
test "is_integer" {
  // 1/2 is not an integer
  let a = new_unchecked(1L, 2L)
  assert_false(a.is_integer())

  // 1 is an integer
  let a = new_unchecked(1L, 1L)
  assert_true(a.is_integer())

  // 0 is an integer
  let a = new_unchecked(0L, 1L)
  assert_true(a.is_integer())

  // -1 is an integer
  let a = new_unchecked(-1L, 1L)
  assert_true(a.is_integer())
}

///|
test "eq and compare" {
  // 1/2 < 2/3
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(2L, 3L)
  assert_eq(Compare::compare(a, b), -1)
  assert_true(a != b)

  // -1/2 > -2/3
  let a = new_unchecked(-1L, 2L)
  let b = new_unchecked(-2L, 3L)
  assert_eq(Compare::compare(a, b), 1)
  assert_true(a != b)

  // 1/2 == 1/2
  let a = new_unchecked(1L, 2L)
  let b = new_unchecked(1L, 2L)
  assert_eq(Compare::compare(a, b), 0)
  assert_true(a == b)
}

///|
test "compare no overflow" {
  let p = new_unchecked(-3L, -9223372036854775808L)
  assert_true(Compare::compare(p, -p) > 0)
}

///|
test "from_double normal case" {
  @debug.assert_eq(from_double(0.5), new_unchecked(1L, 2L))
}

///|
test "from_double edge case" {
  @debug.assert_eq(
    from_double(9_223_372_036_800_000_000.0),
    new_unchecked(9_223_372_036_800_000_000L, 1L),
  )
}
