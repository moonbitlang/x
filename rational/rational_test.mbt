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
test "new" {
  // 1/2
  let a = @rational.new(1L, 2L).unwrap()
  inspect(a, content="1/2")

  // 1/0
  let a = @rational.new(1L, 0L)
  assert_true(a is None)
}

///|
test "addition" {
  let a = @rational.new(1L, 2L).unwrap()
  let b = @rational.new(1L, 3L).unwrap()
  let result = a + b
  inspect(result, content="5/6")
}

///|
test "subtraction" {
  let a = @rational.new(3L, 4L).unwrap()
  let b = @rational.new(1L, 4L).unwrap()
  let result = a - b
  inspect(result, content="1/2")
}

///|
test "multiplication" {
  let a = @rational.new(2L, 3L).unwrap()
  let b = @rational.new(3L, 4L).unwrap()
  let result = a * b
  inspect(result, content="1/2")
}

///|
test "division" {
  let a = @rational.new(1L, 2L).unwrap()
  let b = @rational.new(3L, 4L).unwrap()
  let result = a / b
  inspect(result, content="2/3")
}

///|
test "panic division by zero" {
  let a = @rational.new(1L, 2L).unwrap()
  let b = @rational.new(0L, 1L).unwrap()
  let _ = a / b
}

///|
test "panic reciprocal of zero" {
  let a = @rational.new(0L, 1L).unwrap()
  let _ = a.reciprocal()
}

///|
test "div_checked" {
  let a = @rational.new(1L, 2L).unwrap()
  let b = @rational.new(3L, 4L).unwrap()
  let result = a.div_checked(b)
  inspect(result, content="2/3")
  let zero = @rational.new(0L, 1L).unwrap()
  let result = @test.expect_error(() => a.div_checked(zero))
  @debug.assert_eq(result, RationalError("division by zero"))
}

///|
test "reciprocal_checked" {
  let a = @rational.new(1L, 2L).unwrap()
  let result = a.reciprocal_checked()
  inspect(result, content="2")
  let zero = @rational.new(0L, 1L).unwrap()
  let result = @test.expect_error(() => zero.reciprocal_checked())
  @debug.assert_eq(result, RationalError("reciprocal of zero"))
}

///|
test "from_double overflow" {
  let result = @test.expect_error(() => @rational.from_double(10.0e200))
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
  let result = @test.expect_error(() => @rational.from_double(-10.0e200))
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
}

///|
test "from_double NaN" {
  let result = @test.expect_error(() => {
    @rational.from_double(@double.not_a_number)
  })
  @debug.assert_eq(
    result,
    RationalError("Rational::from_double: cannot convert NaN"),
  )
}

///|
test "from_double overflow edge case" {
  let result = @test.expect_error(() => {
    @rational.from_double(9_223_372_036_854_775_807.1)
  })
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
  let result = @test.expect_error(() => {
    @rational.from_double(-9_223_372_036_854_775_807.1)
  })
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
}

///|
test "from_double infinity" {
  let result = @test.expect_error(() => @rational.from_double(@double.infinity))
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
  let result = @test.expect_error(() => {
    @rational.from_double(@double.neg_infinity)
  })
  @debug.assert_eq(result, RationalError("Rational::from_double: overflow"))
}

///|
test "from_double" {
  let a : Array[Double] = [
    0.5, 5, 29.97, -29.97, 63.5, 126.5, 127.0, 127.5, -63.5, -126.5, -127.0, -127.5,
  ]
  debug_inspect(
    a.map(@rational.from_double),
    content=(
      #|[
      #|  1/2,
      #|  5,
      #|  2997/100,
      #|  -2997/100,
      #|  127/2,
      #|  253/2,
      #|  127,
      #|  255/2,
      #|  -127/2,
      #|  -253/2,
      #|  -127,
      #|  -255/2,
      #|]
    ),
  )
}

///|
test "rational arbitrary" {
  let samples : Array[@rational.Rational64] = @quickcheck.samples(20)
  debug_inspect(
    samples,
    content=(
      #|[
      #|  0,
      #|  0,
      #|  0,
      #|  0,
      #|  2/3,
      #|  -2/5,
      #|  1,
      #|  1/6,
      #|  3/2,
      #|  -1/2,
      #|  9/5,
      #|  5/3,
      #|  -2,
      #|  7/12,
      #|  -2/9,
      #|  -8/15,
      #|  0,
      #|  -5/6,
      #|  3/4,
      #|  -3/7,
      #|]
    ),
  )
}

///|
test "rational equality" {
  let a = @rational.new(1L, 2L).unwrap()
  let b = @rational.new(2L, 4L).unwrap()
  let c = @rational.new(1L, 3L).unwrap()
  inspect(a == b, content="true")
  inspect(a == c, content="false")
  let a = @rational.new(-3L, -9223372036854775808L)
  let b = @rational.new(-1L, -9223372036854775808L)
  assert_true(a is None)
  assert_true(b is None)
  let x = @rational.new(-43L, 3689348814741910693L).unwrap()
  let y = @rational.new(5L, -43L).unwrap()
  inspect(x == y, content="false")
}

///|
test "compare no overflow (int64 max denom)" {
  let max = 9223372036854775807L
  let a = @rational.new(1L, max).unwrap()
  let b = @rational.new(2L, max).unwrap()
  @test.assert_eq(Compare::compare(a, b), -1)

  let x = @rational.new(-43L, 3689348814741910693L).unwrap()
  let y = @rational.new(5L, -43L).unwrap()
  assert_true(Compare::compare(x, y) > 0)
}

///|
test "compare fixed-width boundary values" {
  let int_max = @int.MAX_VALUE
  let a = @rational.new(1, int_max).unwrap()
  let b = @rational.new(2, int_max).unwrap()
  @test.assert_eq(Compare::compare(a, b), -1)

  let int64_max = @int64.MAX_VALUE
  let large_negative = @rational.new(@int64.MIN_VALUE, 1L).unwrap()
  let half_large_negative = @rational.new(-int64_max, 2L).unwrap()
  @test.assert_eq(Compare::compare(large_negative, half_large_negative), -1)
  @test.assert_eq(Compare::compare(half_large_negative, large_negative), 1)

  let positive = @rational.new(int64_max - 1L, int64_max).unwrap()
  let negative = @rational.new(-1L, int64_max).unwrap()
  @test.assert_eq(Compare::compare(positive, negative), 1)
}

///|
test "int64 comparison matches bigint" {
  let numerators : Array[Int64] = [
    @int64.MIN_VALUE,
    @int64.MIN_VALUE + 1L,
    -7540113804746346429L,
    -43L,
    -1L,
    0L,
    1L,
    43L,
    7540113804746346429L,
    @int64.MAX_VALUE,
  ]
  let denominators : Array[Int64] = [
    1L,
    2L,
    3L,
    43L,
    2880067194370816120L,
    @int64.MAX_VALUE,
  ]
  for numerator1 in numerators {
    for denominator1 in denominators {
      let rational1 = @rational.new(numerator1, denominator1).unwrap()
      let big_rational1 = @rational.new(
        BigInt::from_int64(numerator1),
        BigInt::from_int64(denominator1),
      ).unwrap()
      for numerator2 in numerators {
        for denominator2 in denominators {
          let rational2 = @rational.new(numerator2, denominator2).unwrap()
          let big_rational2 = @rational.new(
            BigInt::from_int64(numerator2),
            BigInt::from_int64(denominator2),
          ).unwrap()
          @test.assert_eq(
            Compare::compare(Compare::compare(rational1, rational2), 0),
            Compare::compare(Compare::compare(big_rational1, big_rational2), 0),
          )
        }
      }
    }
  }
}
