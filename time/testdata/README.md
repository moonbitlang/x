# Timezone test data

The arithmetic and field-edit tests use complete TZif files for `Europe/Paris`
and `Asia/Pyongyang` compiled from **IANA tzdb 2024a**. The unmodified binaries
are committed as [`Europe/Paris.tzif`](Europe/Paris.tzif) and
[`Asia/Pyongyang.tzif`](Asia/Pyongyang.tzif).

The prebuild rules in [`moon.pkg`](../moon.pkg) use Moon's built-in `:embed`
command to generate white-box test bindings, which are loaded through
`Zone::from_tzif`. Tests do not read the host's database or need network access,
so all backends use the same rules. The two generated bindings are Git-ignored.
[`time/.moonignore`](../.moonignore) excludes both the inputs and generated
bindings from published packages.

## Expected clock changes

These historical transitions are in the files' explicit tables. Each row shows
the last ordinary second before a change and the next second after it.

| Zone | Transition instant (UTC) | Local time before | Local time after |
| --- | --- | --- | --- |
| Paris | 2024-03-31 01:00:00 | March 31 01:59:59 CET (+01:00) | March 31 03:00:00 CEST (+02:00) |
| Paris | 2024-10-27 01:00:00 | October 27 02:59:59 CEST (+02:00) | October 27 02:00:00 CET (+01:00) |
| Pyongyang | 2015-08-14 15:00:00 | August 14 23:59:59 (+09:00) | August 14 23:30:00 (+08:30) |
| Pyongyang | 2018-05-04 15:00:00 | May 4 23:29:59 (+08:30) | May 5 00:00:00 (+09:00) |

For example, adding two elapsed hours to Paris's October 27 **01:30 CEST**
produces **02:30 CET**, the second occurrence of that local time. Adding one
calendar day to March 30 at noon produces March 31 at noon, only **23 elapsed
hours** later.

Pyongyang exercises a **30-minute** gap and overlap caused by changes to the
standard offset, rather than DST. Its designation is `KST` on both sides of
these changes. The 2018 gap also crosses midnight: editing May 4 **23:15** to
minute **45** with compatible disambiguation produces May 5 **00:15**. Its
`KST-9` footer keeps UTC+9 thereafter, which is checked by winter-to-summer edits.

## Recurring rules after the transition table

The POSIX rule in a TZif footer describes annual changes after the explicit
transition table ends. Paris's last explicit transition is 2037-10-25 01:00:00
UTC. Its footer, `CET-1CEST,M3.5.0,M10.5.0/3`, specifies:

- Standard time is CET at UTC+1; daylight time is CEST at UTC+2.
- On March's last Sunday, 02:00 standard time advances to 03:00 daylight time.
- On October's last Sunday, 03:00 daylight time returns to 02:00 standard time.

A separate 2040 test exercises this rule: March 25 skips 02:00–02:59, and
October 28 repeats 02:00–02:59. These are projections of the pinned rules,
not predictions of future legislation.

The two tests using a synthetic `Seconds` zone deliberately put a 28-second
gap and overlap only one minute apart. This isolates field-edit and arithmetic
edge cases; it does not represent a named geographical zone.

## Provenance and reproduction

Sources are the public-domain IANA
[`tzdata2024a.tar.gz`](https://data.iana.org/time-zones/releases/tzdata2024a.tar.gz)
and [`tzcode2024a.tar.gz`](https://data.iana.org/time-zones/releases/tzcode2024a.tar.gz).
The relevant zone/rule definitions are in
[`europe`](https://data.iana.org/time-zones/tzdb-2024a/europe) and
[`asia`](https://data.iana.org/time-zones/tzdb-2024a/asia).

Extract both archives into the same directory, then run:

```sh
make CFLAGS=-DHAVE_GETTEXT=0 zic
./zic -b fat -d zoneinfo europe asia
```

`fat` retains Paris's explicit transitions through 2037 as well as its
recurring footer rules, allowing both paths to be exercised. No date-range
truncation or handwritten zone definitions are used. Copy the two output files
to the corresponding `.tzif` paths above. `moon test time` generates the bindings
automatically; do not edit or commit those generated files. The combined binary
size is 3,199 bytes (2,962 for Paris and 237 for Pyongyang); they are test-only
fixtures, not a bundled runtime database.

SHA-256 checksums:

| File | SHA-256 |
| --- | --- |
| tzdata2024a.tar.gz | `0d0434459acbd2059a7a8da1f3304a84a86591f6ed69c6248fffa502b6edffe3` |
| tzcode2024a.tar.gz | `80072894adff5a458f1d143e16e4ca1d8b2a122c9c5399da482cb68cba6a1ff8` |
| zoneinfo/Europe/Paris | `ab77a1488a2dd4667a4f23072236e0d2845fe208405eec1b4834985629ba7af8` |
| zoneinfo/Asia/Pyongyang | `ffe8371a70c0b5f0d7e17024b571fd8c5a2e2d40e63a8be78e839fbd1a540ec1` |
