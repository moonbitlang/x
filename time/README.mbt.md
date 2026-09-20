# Moonbit/Core Time

## Overview

Package time provides functionality for measuring and manipulating time.

The calendrical calculations always assume a ISO 8601 calendar, with no leap seconds.

To create a datatime that represents the current time, you need to obtain the unix second and time zone offset from the [wasi](https://mooncakes.io/docs/#/peter-jerry-ye/wasi/) package (wasm-gc backend) or other FFI functions, and manually create a datetime.

```moonbit check
///|
test {
  // creates a UTC+8 fixed time zone.
  let zone = @time.fixed_zone("Asia/Shanghai", 8 * 60 * 60)

  // creates a ZonedDateTime from unix second and time zone.
  let date_time = @time.unix(1714227729L, nanosecond=1000, zone~)
  inspect(date_time, content="2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]")
}
```

Use `@time.Zone::from_tzif(id, data)` to load a caller-supplied TZif v1–v4 file.
`data` is a `BytesView`; complete `Bytes` values can also be passed. The `id`
labels the zone; the constructor does not look up timezone database files.
`Zone::from_tzif2` is deprecated in favor of this interface.

TZif loading currently uses explicit transitions only. Recurring footer rules
are parsed but not evaluated, so the final recorded offset continues
indefinitely. Leap-bearing transition times are converted to Unix seconds.
For v4, transitions needing missing earlier leap history raise an error;
after leap-table expiration, the last known correction is retained.

## TODOs

- Convert from/to RFC format string.
- Custom string formatter.
- Support the time zone offset transition at daylight saving time.
- Support monotonic clock to accurately measure the elapsed time.
- Support different calendar system, such as Chinese calendar system.
