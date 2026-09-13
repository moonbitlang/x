# Moonbit/Core Time

## Overview

Package time provides functionality for measuring and manipulating time.

The calendrical calculations always assume a ISO 8601 calendar, with no leap seconds.

To create a datatime that represents the current time, you need to obtain the unix second and time zone offset from the [wasi](https://mooncakes.io/docs/#/peter-jerry-ye/wasi/) package (wasm-gc backend) or other FFI functions, and manually create a datetime.

```moonbit check
///|
test {
  // creates a UTC+8 fixed time zone.
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)

  // creates a ZonedDateTime from unix second and time zone.
  let date_time = @time.unix(1714227729L, nanosecond=1000, zone~)
  inspect(date_time, content="2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]")
}
```

A `ZonedDateTime` parsed from a string with an explicit offset keeps that offset
for further calculations:

```moonbit check
///|
test {
  let date_time = @time.ZonedDateTime::parse_str("2026-09-12T14:30:00+05:30")
  inspect(date_time.add_seconds(0L), content="2026-09-12T14:30:00+05:30")
}
```

## TODOs

- Convert from/to RFC format string.
- Custom string formatter.
- Support the time zone offset transition at daylight saving time.
- Support monotonic clock to accurately measure the elapsed time.
- Support different calendar system, such as Chinese calendar system.

## Deficiencies/Warnings

- The library does not have a TZ implementation yet. Use Zone and ZonedDateTime with care. The data structures can do a roundtrip without
validation and that is the limit of the existing implementation.
- The API for `ZonedDateTime` is intentionally left open so that programs can use the offset directly.
- Calculations on `ZonedDateTime` look the offset up again from the zone, so a value parsed from a string with an explicit offset is treated as a fixed offset zone.
- A zone id of `""` marks a value that had no bracketed zone id in its string form; it is rendered without a `[zone]` suffix.
- In the future the `ZoneOffset` should become opaque.
