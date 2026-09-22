# Windows timezone snapshots

These fixtures contain the unmodified 44-byte `REG_TZI_FORMAT` annual records
from the Unicode project's Windows registry export at
[`icu-demos` revision 3862ba73](https://github.com/unicode-org/icu-demos/blob/3862ba73f29a1515e9a91fb1814271e470b6fb90/WinTZ/src/com/ibm/icu/dev/tools/wintz/TimeZone.reg).
They are historical test data, not a current database distributed to users.

| Fixture | Registry key | Stored years | Bytes |
| --- | --- | --- | --- |
| `pyongyang.bin` | `North Korea Standard Time` | 2014–2019 | 272 |
| `moscow.bin` | `Russian Standard Time` | 2010–2015 | 272 |

Each file starts with `FirstEntry` and `LastEntry` as two little-endian `u32`
values, followed by the yearly records in order. This envelope is also the
private format assembled in MoonBit from the native annual-rule reads. The
record layout is documented by Microsoft's
[`DYNAMIC_TIME_ZONE_INFORMATION`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/ns-timezoneapi-dynamic_time_zone_information).
The US Eastern 2007 record in `zone_windows_data_wbtest.mbt` is from the same export,
with field annotations to make the binary layout reviewable.

The native reader captures the current zone once, then uses
[`GetTimeZoneInformationForYear`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-gettimezoneinformationforyear)
for annual rules. C marshals those records; MoonBit validates the year range
and assembles the snapshot. When dynamic DST is disabled, or no historical
year range exists, the current rule is retained instead.

Year-range discovery detects
[`GetDynamicTimeZoneInformationEffectiveYears`](https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/nf-timezoneapi-getdynamictimezoneinformationeffectiveyears)
with `GetProcAddress`. Windows 8 and later use this API; Windows 7 reads only
`FirstEntry` and `LastEntry` from the registry. An API error is preserved, not
silently retried through the registry. Both paths use the same annual-rule API.

Advapi32 is linked with `#pragma comment(lib, "advapi32.lib")` on MSVC-compatible
compilers; MinGW builds need `-ladvapi32`. Only the optional year-range API needs
a function pointer; registry calls remain direct.

CI builds with Windows 7 declarations and runs native tests with UTC and US
Eastern as the local zone. Tests compare the registry year bounds with runtime
API discovery and compare snapshot offsets with Win32's per-year converter.
These tests run on the current Windows runner, so they do not establish
compatibility of the entire MoonBit/C runtime with a Windows 7 installation.

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

To reproduce, download the linked UTF-16 registry export as `TimeZone.reg` and
run the following script in a scratch directory. Copy the resulting binaries
here. Moon's `:embed` rules generate the Git-ignored test bindings; `.moonignore`
excludes both the binaries and generated bindings from published packages.

```python
import pathlib
import re
import struct

text = pathlib.Path("TimeZone.reg").read_text(encoding="utf-16")
text = text.replace("\\\n", "")
sections = dict(re.findall(r"\[([^\]]+)\]([^\[]*)", text))
root = r"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones"
for key, filename in [
    ("North Korea Standard Time", "pyongyang.bin"),
    ("Russian Standard Time", "moscow.bin"),
]:
    body = sections[root + "\\" + key + r"\Dynamic DST"]
    records = {
        int(year): bytes.fromhex(data.replace(",", " "))
        for year, data in re.findall(r'"(\d+)"=hex:([0-9a-f,\s]+)', body)
    }
    first, last = min(records), max(records)
    data = struct.pack("<II", first, last)
    data += b"".join(records[year] for year in range(first, last + 1))
    pathlib.Path(filename).write_bytes(data)
```
