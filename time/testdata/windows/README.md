# Windows timezone test data

The named records in [`windows_fixtures_wbtest.mbt`](../../windows_fixtures_wbtest.mbt)
preserve the annual rule fields from the Unicode project's Windows registry export at
[`icu-demos` revision 3862ba73](https://github.com/unicode-org/icu-demos/blob/3862ba73f29a1515e9a91fb1814271e470b6fb90/WinTZ/src/com/ibm/icu/dev/tools/wintz/TimeZone.reg).
They are historical test data, not a current database distributed to users.

| Fixture | Registry key | Years |
| --- | --- | --- |
| `pyongyang_windows_rules` | `North Korea Standard Time` | 2014–2019 |
| `moscow_windows_rules` | `Russian Standard Time` | 2010–2015 |
| `eastern_windows_record` | `Eastern Standard Time` | 2007 |

Each fixture lists the bias fields and the two `SYSTEMTIME` transition dates
as MoonBit records. Values are in Windows units: biases in minutes, weekday
zero for Sunday, and day 1–5 for the occurrence within a month when year is zero.
A zero month means no seasonal transition. The fields correspond to
[`TIME_ZONE_INFORMATION`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/ns-timezoneapi-time_zone_information);
there is no private binary snapshot format or generated test binding.

The native reader captures the current zone once, then uses
[`GetTimeZoneInformationForYear`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-gettimezoneinformationforyear)
for annual rules. FFI accessors read the native fields into MoonBit records
before the next annual API call replaces the working result. MoonBit validates
and converts those records into the zone's transitions and recurring endpoints.
When dynamic DST is disabled, or no historical year range exists, the current
rule is retained instead.

Year-range discovery detects
[`GetDynamicTimeZoneInformationEffectiveYears`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-getdynamictimezoneinformationeffectiveyears)
with `GetProcAddress`. Windows 8 and later use this API; Windows 7 reads only
`FirstEntry` and `LastEntry` from the registry. An API error is preserved, not
silently retried through the registry. Both paths use the same annual-rule API.

Advapi32 is linked with `#pragma comment(lib, "advapi32.lib")` on MSVC-compatible
compilers; MinGW builds need `-ladvapi32`. Only the optional year-range API needs
a function pointer; registry calls remain direct.

Native integration tests use the runner's configured local zone. They compare
registry year bounds with runtime API discovery and snapshot offsets with
Win32's per-year converter. Execution on Windows 7 itself remains unverified.

Expected offsets:

| Zone | UTC instant | Before | After |
| --- | --- | --- | --- |
| Pyongyang | 2015-08-14 15:00:00 | +09:00 | +08:30 |
| Pyongyang | 2018-05-04 15:00:00 | +08:30 | +09:00 |
| Moscow | 2011-03-26 23:00:00 | +03:00 | +04:00 |
| Moscow | 2014-10-25 22:00:00 | +04:00 | +03:00 |

Moscow remains +04:00 across New Year 2012 and 2014. Pyongyang's annual
records also change representation at New Year without changing the effective
offset. The tests compare Pyongyang with the existing IANA fixture at its
transitions and annual boundaries. Windows encodes its political changes with
seasonal fields, so the offsets agree while the DST flags can differ.

The end-of-day `23:59:59.999` convention is
[documented by Microsoft](https://devblogs.microsoft.com/oldnewthing/20180309-00/?p=98195).
We normalize it to midnight, as
[Noda Time does](https://nodatime.org/3.3.x/api/NodaTime.TimeZones.BclDateTimeZone.html).
January 1 at midnight also acts as a year-boundary marker, as explained in
[.NET's adjustment-rule implementation](https://github.com/dotnet/runtime/blob/v10.0.0/src/libraries/System.Private.CoreLib/src/System/TimeZoneInfo.AdjustmentRule.cs).

To check the fixture values against the source, download the linked UTF-16
registry export as `TimeZone.reg`. This script prints its annual fields in the
same order used by the fixtures, without creating a binary fixture:

```python
import pathlib
import re
import struct

text = pathlib.Path("TimeZone.reg").read_text(encoding="utf-16")
text = text.replace("\\\n", "")
sections = dict(re.findall(r"\[([^\]]+)\]([^\[]*)", text))
root = r"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones"
fields = ("year", "month", "weekday", "day", "hour", "minute", "second", "millisecond")
for key in ("North Korea Standard Time", "Russian Standard Time", "Eastern Standard Time"):
    body = sections[root + "\\" + key + r"\Dynamic DST"]
    for year, data in re.findall(r'"(\d+)"=hex:([0-9a-f,\s]+)', body):
        values = struct.unpack("<iii16H", bytes.fromhex(data.replace(",", " ")))
        print(key, year, dict(zip(("bias", "standard_bias", "daylight_bias"), values[:3])))
        print("  standard_date:", dict(zip(fields, values[3:11])))
        print("  daylight_date:", dict(zip(fields, values[11:])))
```
