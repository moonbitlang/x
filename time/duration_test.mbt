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
test "from_str" {
  inspect((@string.FromStr::from_str("PT0S") : @time.Duration), content="PT0S")
  inspect(
    (@string.FromStr::from_str("PT1H2M3.456789S") : @time.Duration),
    content="PT1H2M3.456789S",
  )
  inspect(
    (@string.FromStr::from_str("PT-1H-2M-3.456789S") : @time.Duration),
    content="PT-1H-2M-3.456789S",
  )
  inspect(
    (@string.FromStr::from_str("PT0.45S") : @time.Duration),
    content="PT0.45S",
  )
  @test.assert_raise(() => {
    (@string.FromStr::from_str("PT0.000.45S") : @time.Duration)
  })
  @test.assert_raise(() => {
    (@string.FromStr::from_str("P1Y2M3DT4H5M6S") : @time.Duration)
  })
}

///|
test "getters" {
  let d = @time.Duration::of(hours=1L, minutes=2L, seconds=3L, nanoseconds=400L)
  inspect(d.seconds(), content="3723")
  inspect(d.nanoseconds(), content="400")
}

///|
test "is_zero" {
  inspect(@time.Duration::zero().is_zero(), content="true")
  inspect(@time.Duration::of().is_zero(), content="true")
  inspect(@time.Duration::of(hours=1L).is_zero(), content="false")
  inspect(@time.Duration::of(minutes=1L).is_zero(), content="false")
  inspect(@time.Duration::of(seconds=1L).is_zero(), content="false")
  inspect(@time.Duration::of(nanoseconds=1L).is_zero(), content="false")
}

///|
test "is_neg" {
  inspect(@time.Duration::zero().is_neg(), content="false")
  inspect(@time.Duration::of(seconds=1L).is_neg(), content="false")
  inspect(@time.Duration::of(seconds=-1L).is_neg(), content="true")
  inspect(
    @time.Duration::of(seconds=-1L, nanoseconds=1L).is_neg(),
    content="true",
  )
  inspect(@time.Duration::of(nanoseconds=1L).is_neg(), content="false")
}

///|
test "add_seconds" {
  inspect(@time.Duration::zero().add_seconds(0L), content="PT0S")
  inspect(@time.Duration::zero().add_seconds(1L), content="PT1S")
  inspect(@time.Duration::zero().add_seconds(-1L), content="PT-1S")
  inspect(
    @time.Duration::zero().add_seconds(@int64.MAX_VALUE),
    content="PT2562047788015215H30M7S",
  )
  inspect(
    @time.Duration::zero().add_seconds(@int64.MIN_VALUE),
    content="PT-2562047788015215H-30M-8S",
  )
  @test.assert_raise(() => {
    @time.Duration::of(seconds=1L).add_seconds(@int64.MAX_VALUE)
  })
  @test.assert_raise(() => {
    @time.Duration::of(seconds=-1L).add_seconds(@int64.MIN_VALUE)
  })
}

///|
test "with_seconds" {
  let d = @time.Duration::of(seconds=20L)
  inspect(d.with_seconds(20L), content="PT20S")
  inspect(d.with_seconds(30L), content="PT30S")
}

///|
test "with_nanoseconds" {
  let d = @time.Duration::of(nanoseconds=1000L)
  inspect(d.with_nanoseconds(1000), content="PT0.000001S")
  inspect(d.with_nanoseconds(2000), content="PT0.000002S")
  @test.assert_raise(() => d.with_nanoseconds(1_000_000_000))
}

///|
fn[T : Hash] hash_of(x : T) -> Int {
  let hasher = Hasher(seed=0)
  hasher.combine(x)
  hasher.finalize()
}

///|
test "from_str negative fractional seconds" {
  // A negative fraction without whole seconds keeps its sign.
  inspect(
    (@string.FromStr::from_str("PT-0.5S") : @time.Duration),
    content="PT-0.5S",
  )
  inspect(
    (@string.FromStr::from_str("PT-1.5S") : @time.Duration),
    content="PT-1.5S",
  )
  inspect(
    (@string.FromStr::from_str("PT-0.000000001S") : @time.Duration),
    content="PT-0.000000001S",
  )
  // Nothing may follow the seconds component.
  @test.assert_raise(() => (@string.FromStr::from_str("PT1S2") : @time.Duration))
  @test.assert_raise(() => {
    (@string.FromStr::from_str("PT1Sjunk") : @time.Duration)
  })
}

///|
test "from_hours" {
  inspect(@time.Duration::from_hours(0L), content="PT0S")
  inspect(@time.Duration::from_hours(2L), content="PT2H")
  inspect(@time.Duration::from_hours(-1L), content="PT-1H")
  @test.assert_raise(() => @time.Duration::from_hours(@int64.MAX_VALUE))
}

///|
test "from_minutes" {
  inspect(@time.Duration::from_minutes(0L), content="PT0S")
  inspect(@time.Duration::from_minutes(90L), content="PT1H30M")
  inspect(@time.Duration::from_minutes(-1L), content="PT-1M")
  @test.assert_raise(() => @time.Duration::from_minutes(@int64.MAX_VALUE))
}

///|
test "from_seconds" {
  inspect(@time.Duration::from_seconds(0L), content="PT0S")
  inspect(@time.Duration::from_seconds(3600L), content="PT1H")
  inspect(@time.Duration::from_seconds(-1L), content="PT-1S")
}

///|
test "from_millis" {
  inspect(@time.Duration::from_millis(0L), content="PT0S")
  inspect(@time.Duration::from_millis(1L), content="PT0.001S")
  inspect(@time.Duration::from_millis(234L), content="PT0.234S")
  inspect(@time.Duration::from_millis(1500L), content="PT1.5S")
  inspect(@time.Duration::from_millis(-1L), content="PT-0.001S")
  inspect(@time.Duration::from_millis(-1500L), content="PT-1.5S")
}

///|
test "from_nanoseconds" {
  inspect(@time.Duration::from_nanoseconds(0L), content="PT0S")
  inspect(@time.Duration::from_nanoseconds(1L), content="PT0.000000001S")
  inspect(@time.Duration::from_nanoseconds(1_500_000_000L), content="PT1.5S")
  inspect(@time.Duration::from_nanoseconds(-1L), content="PT-0.000000001S")
}

///|
test "to_millis" {
  inspect(@time.Duration::zero().to_millis(), content="0")
  inspect(@time.Duration::from_millis(1500L).to_millis(), content="1500")
  inspect(
    @time.Duration::of(seconds=1L, nanoseconds=234_000_000L).to_millis(),
    content="1234",
  )
  // Sub-millisecond precision is truncated.
  inspect(
    @time.Duration::of(seconds=1L, nanoseconds=234_567_890L).to_millis(),
    content="1234",
  )
  // Negative durations keep their sign.
  inspect(
    @time.Duration::of(seconds=-1L, nanoseconds=500_000_000L).to_millis(),
    content="-500",
  )
  inspect(@time.Duration::of(nanoseconds=-1L).to_millis(), content="0")
}

///|
test "to_hours and to_minutes" {
  let d = @time.Duration::of(hours=2L, minutes=30L, seconds=45L)
  inspect(d.to_hours(), content="2")
  inspect(d.to_minutes(), content="150")
  inspect(@time.Duration::of(seconds=59L).to_minutes(), content="0")
  // Truncates towards zero for negative durations.
  inspect(@time.Duration::of(seconds=-3661L).to_hours(), content="-1")
  inspect(@time.Duration::of(seconds=-3661L).to_minutes(), content="-61")
  inspect(@time.Duration::of(nanoseconds=-1L).to_hours(), content="0")
  // Equivalent lengths truncate alike no matter how their secs/nanos split
  // is stored: 3600s - 1ns is 3599.999999999s, i.e. 0 hours and 59 minutes.
  inspect(
    @time.Duration::of(seconds=3600L, nanoseconds=-1L).to_hours(),
    content="0",
  )
  inspect(
    @time.Duration::of(seconds=3600L, nanoseconds=-1L).to_minutes(),
    content="59",
  )
}

///|
test "is_positive" {
  inspect(@time.Duration::zero().is_positive(), content="false")
  inspect(@time.Duration::of(seconds=1L).is_positive(), content="true")
  inspect(@time.Duration::of(nanoseconds=1L).is_positive(), content="true")
  inspect(@time.Duration::of(seconds=-1L).is_positive(), content="false")
  inspect(@time.Duration::of(nanoseconds=-1L).is_positive(), content="false")
  inspect(
    @time.Duration::of(seconds=-1L, nanoseconds=500_000_000L).is_positive(),
    content="false",
  )
  inspect(
    @time.Duration::of(seconds=1L, nanoseconds=-500_000_000L).is_positive(),
    content="true",
  )
}

///|
test "subtract_hours" {
  let d = @time.Duration::of(hours=2L)
  inspect(d.subtract_hours(1L), content="PT1H")
  inspect(d.subtract_hours(3L), content="PT-1H")
  inspect(d.subtract_hours(0L), content="PT2H")
  inspect(d.subtract_hours(-1L), content="PT3H")
}

///|
test "subtract_minutes" {
  let d = @time.Duration::of(minutes=30L)
  inspect(d.subtract_minutes(20L), content="PT10M")
  inspect(d.subtract_minutes(45L), content="PT-15M")
  inspect(d.subtract_minutes(0L), content="PT30M")
}

///|
test "subtract_seconds" {
  let d = @time.Duration::of(seconds=5L)
  inspect(d.subtract_seconds(3L), content="PT2S")
  inspect(d.subtract_seconds(8L), content="PT-3S")
  inspect(d.subtract_seconds(0L), content="PT5S")
}

///|
test "subtract_nanoseconds" {
  let d = @time.Duration::of(nanoseconds=1000L)
  inspect(d.subtract_nanoseconds(400L), content="PT0.0000006S")
  inspect(d.subtract_nanoseconds(1000L), content="PT0S")
  inspect(d.subtract_nanoseconds(1400L), content="PT-0.0000004S")
}

///|
test "subtract_duration and op_sub" {
  let a = @time.Duration::of(seconds=5L)
  let b = @time.Duration::of(seconds=2L)
  inspect(a.subtract_duration(b), content="PT3S")
  inspect(a.op_sub(b), content="PT3S")
  inspect(b.subtract_duration(a), content="PT-3S")
  inspect(a.subtract_duration(@time.Duration::zero()), content="PT5S")
  // Sub-second operands keep their exact length.
  inspect(
    @time.Duration::of(seconds=1L).subtract_duration(
      @time.Duration::of(nanoseconds=1L),
    ),
    content="PT0.999999999S",
  )
}

///|
test "negated, op_neg and abs" {
  let d = @time.Duration::of(hours=1L, minutes=2L, seconds=3L)
  inspect(d.negated(), content="PT-1H-2M-3S")
  inspect(d.op_neg(), content="PT-1H-2M-3S")
  inspect(d.negated().negated(), content="PT1H2M3S")
  inspect(@time.Duration::zero().negated(), content="PT0S")
  inspect(d.abs(), content="PT1H2M3S")
  inspect(d.negated().abs(), content="PT1H2M3S")
  // Durations shorter than one second are still negative.
  inspect(
    @time.Duration::of(nanoseconds=-1L).negated(),
    content="PT0.000000001S",
  )
  inspect(@time.Duration::of(nanoseconds=-1L).abs(), content="PT0.000000001S")
  inspect(
    @time.Duration::of(seconds=-1L, nanoseconds=500_000_000L).abs(),
    content="PT0.5S",
  )
  // Negating Int64::MIN_VALUE seconds is not representable.
  @test.assert_raise(() => {
    @time.Duration::of(seconds=@int64.MIN_VALUE).negated()
  })
  @test.assert_raise(() => {
    @time.Duration::of(seconds=@int64.MIN_VALUE, nanoseconds=-1L).negated()
  })
}

///|
test "multiplied_by" {
  let d = @time.Duration::of(seconds=2L)
  inspect(d.multiplied_by(3L), content="PT6S")
  inspect(d.multiplied_by(1L), content="PT2S")
  inspect(d.multiplied_by(0L), content="PT0S")
  inspect(d.multiplied_by(-1L), content="PT-2S")
  inspect(
    @time.Duration::of(nanoseconds=500_000_000L).multiplied_by(3L),
    content="PT1.5S",
  )
  @test.assert_raise(() => d.multiplied_by(@int64.MAX_VALUE))
  // Scaling goes through the nanosecond count, which does not fit in Int64
  // for durations longer than ~292 years: raise instead of wrapping.
  let long = @time.Duration::of(seconds=10_000_000_000L)
  @test.assert_raise(() => long.multiplied_by(2L))
}

///|
test "divided_by" {
  let d = @time.Duration::of(seconds=10L)
  inspect(d.divided_by(1L), content="PT10S")
  inspect(d.divided_by(2L), content="PT5S")
  inspect(d.divided_by(4L), content="PT2.5S")
  inspect(d.divided_by(-2L), content="PT-5S")
  inspect(d.divided_by(3L), content="PT3.333333333S")
  inspect(@time.Duration::of(nanoseconds=1L).divided_by(2L), content="PT0S")
  @test.assert_raise(() => d.divided_by(0L))
  // A duration that does not fit in an Int64 nanosecond count raises instead
  // of silently wrapping to a wrong sign.
  let long = @time.Duration::of(seconds=10_000_000_000L)
  @test.assert_raise(() => long.divided_by(2L))
}

///|
test "min and max" {
  let a = @time.Duration::of(seconds=1L)
  let b = @time.Duration::of(seconds=2L)
  let neg = @time.Duration::of(seconds=-1L)
  inspect(a.min(b), content="PT1S")
  inspect(b.min(a), content="PT1S")
  inspect(a.min(a), content="PT1S")
  inspect(a.max(b), content="PT2S")
  inspect(b.max(a), content="PT2S")
  inspect(neg.max(a), content="PT1S")
  inspect(neg.min(a), content="PT-1S")
}

///|
test "eq compare and hash" {
  let one = @time.Duration::of(seconds=1L)
  let two = @time.Duration::of(seconds=2L)
  inspect(one == one, content="true")
  inspect(one == two, content="false")
  inspect(Compare::compare(one, one), content="0")
  inspect(Compare::compare(one, two), content="-1")
  inspect(Compare::compare(two, one), content="1")
  inspect(one < two, content="true")
  inspect(two > one, content="true")
  // The same length can be stored with different secs/nanos splits, so
  // ordering and equality must not depend on the internal representation.
  let half_a = @time.Duration::of(seconds=-1L, nanoseconds=500_000_000L)
  let half_b = @time.Duration::of(nanoseconds=-500_000_000L)
  inspect(half_a.to_nanoseconds(), content="-500000000")
  inspect(half_b.to_nanoseconds(), content="-500000000")
  inspect(half_a == half_b, content="true")
  inspect(Compare::compare(half_a, half_b), content="0")
  inspect(hash_of(half_a) == hash_of(half_b), content="true")
  inspect(half_a < @time.Duration::zero(), content="true")
  inspect(@time.Duration::zero() > half_b, content="true")
  // The most negative split still orders by its fields instead of wrapping
  // while being normalized.
  let min_split = @time.Duration::of(seconds=@int64.MIN_VALUE, nanoseconds=-1L)
  let min_whole = @time.Duration::of(seconds=@int64.MIN_VALUE)
  inspect(min_split < min_whole, content="true")
}
