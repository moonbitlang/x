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

// Adapted from pyca/bcrypt's _test_vectors and test_hashpw_nul_byte.
// Source: https://github.com/pyca/bcrypt/blob/main/tests/test_bcrypt.py
// License: Apache-2.0; see LICENSE.pyca-bcrypt in this directory.
// Changes: select $2b$ vectors, decode salts to bytes, and use a fixed salt
// for the NUL test to fit this package's API and keep tests deterministic.

///|
test "pyca bcrypt 2b reference vectors" {
  // Password, decoded 16-byte salt, cost, and complete expected hash.
  let vectors : Array[(Bytes, Bytes, Int, String)] = [
    (
      b"Kk4DQuMMfZL9o", b"\x79\x76\x2B\xE9\x97\x0F\x5B\xE7\x3A\xC7\x7C\x0E\x4F\x0A\x38\x51",
      4, "$2b$04$cVWp4XaNU8a4v1uMRum2SO026BWLIoQMD/TXg5uZV.0P.uO8m3YEm",
    ),
    (
      b"9IeRXmnGxMYbs", b"\xAD\x2F\x62\x4D\x0F\x60\xF3\x2C\xC1\xFF\x9F\x2A\x66\x33\xE5\xB5",
      4, "$2b$04$pQ7gRO7e6wx/936oXhNjrOUNOHL1D0h1N2IDbJZYs.1ppzSof6SPy",
    ),
    (
      b"xVQVbwa1S0M8r", b"\x51\x28\x3F\x9A\x94\x35\x82\xB4\x17\x32\xA6\x99\xAB\xFC\xD5\xBE",
      4, "$2b$04$SQe9knOzepOVKoYXo9xTteNYr6MBwVz4tpriJVe3PNgYufGIsgKcW",
    ),
    (
      b"Zfgr26LWd22Za", b"\x80\x9F\xB5\x64\x0B\x3B\x48\x09\x78\x8D\x0D\xCF\x99\x76\x8B\x49",
      4, "$2b$04$eH8zX.q5Q.j2hO1NkVYJQOM6KxntS/ow3.YzVmFrE4t//CoF4fvne",
    ),
    (
      b"Tg4daC27epFBE", b"\x72\x39\x15\x7F\x24\xD9\xAD\x62\x38\x2C\xD4\xDE\x2B\x5A\x73\x78",
      4, "$2b$04$ahiTdwRXpUG2JLRcIznxc.s1.ydaPGD372bsGs8NqyYjLY1inG5n2",
    ),
    (
      b"xhQPMmwh5ALzW", b"\xA5\x2A\x7D\xF9\xF5\xF6\x8C\x82\x61\xEF\x25\x83\x83\x6D\x50\x1F",
      4, "$2b$04$nQn78dV0hGHf5wUBe0zOFu8n07ZbWWOKoGasZKRspZxtt.vBRNMIy",
    ),
    (
      b"59je8h5Gj71tg", b"\x7B\x16\x70\x7D\xBE\xF0\x89\x58\xBF\xED\x80\x2D\x42\x53\x8A\x57",
      4, "$2b$04$cvXudZ5ugTg95W.rOjMITuM1jC0piCl3zF5cmGhzCibHZrNHkmckG",
    ),
    (
      b"wT4fHJa2N9WSW", b"\x69\xA9\x6F\x92\xCE\x96\x8F\xEF\xB4\x5A\xE1\xB3\x43\x64\xCF\x57",
      4, "$2b$04$YYjtiq4Uh88yUsExO0RNTuEJ.tZlsONac16A8OcLHleWFjVawfGvO",
    ),
    (
      b"uSgFRnQdOgm4S", b"\x60\xD5\x65\x89\xA0\x6B\x6D\x4D\x2C\x64\x18\x5D\x39\xD2\xF5\x84",
      4, "$2b$04$WLTjgY/pZSyqX/fbMbJzf.qxCeTMQOzgL.CimRjMHtMxd/VGKojMu",
    ),
    (
      b"tEPtJZXur16Vg", b"\xE2\x8A\x91\xB8\x1C\xC1\xCA\x91\x21\x81\x2E\xEB\x12\x38\x0E\x7B",
      4, "$2b$04$2moPs/x/wnCfeQ5pCheMcuSJQ/KYjOZG780UjA/SiR.KsYWNrC7SG",
    ),
    (
      b"vvho8C6nlVf9K", b"\x26\xD1\x9A\x10\x10\x92\xE0\x95\x3D\xF4\x8F\x7E\x79\x21\x5B\x48",
      4, "$2b$04$HrEYC/AQ2HS77G78cQDZQ.r44WGcruKw03KHlnp71yVQEwpsi3xl2",
    ),
    (
      b"5auCCY9by0Ruf", b"\xC5\x76\xA2\x51\x58\x43\xF8\xC5\xDD\xA2\x37\x5B\x18\x19\xB9\x4C",
      4, "$2b$04$vVYgSTfB8KVbmhbZE/k3R.ux9A0lJUM4CZwCkHI9fifke2.rTF7MG",
    ),
    (
      b"GtTkR6qn2QOZW", b"\x2E\x1A\x8F\xB5\x3F\x80\x7E\xA9\x20\xA8\xAF\x80\x00\x70\x04\xDD",
      4, "$2b$04$JfoNrR8.doieoI8..F.C1OQgwE3uTeuardy6lw0AjALUzOARoyf2m",
    ),
    (
      b"zKo8vdFSnjX0f", b"\x25\x1E\x4A\xD9\x15\xAE\xF4\xC0\xC6\xD4\xE0\xCF\x1F\x2F\x6A\xE5",
      4, "$2b$04$HP3I0PUs7KBEzMBNFw7o3O7f/uxaZU7aaDot1quHMgB2yrwBXsgyy",
    ),
    (
      b"I9VfYlacJiwiK", b"\xCE\x91\xD7\x8C\xBB\x95\xD6\xE1\xC3\x56\x04\x79\x46\xB8\x9D\x3A",
      4, "$2b$04$xnFVhJsTzsFBTeP3PpgbMeMREb6rdKV9faW54Sx.yg9plf4jY8qT6",
    ),
    (
      b"VFPO7YXnHQbQO", b"\x61\x2A\xFF\x02\x48\xAA\x36\xC5\xED\xF1\x29\xBD\xDA\x8D\x7C\xCF",
      4, "$2b$04$WQp9.igoLqVr6Qk70mz6xuRxE0RttVXXdukpR9N54x17ecad34ZF6",
    ),
    (
      b"VDx5BdxfxstYk", b"\xCE\x26\xEF\x9E\xAA\x6B\x08\x95\x16\x06\x99\x50\x11\xF3\x35\xBD",
      4, "$2b$04$xgZtlonpAHSU/njOCdKztOPuPFzCNVpB4LGicO4/OGgHv.uKHkwsS",
    ),
    (
      b"dEe6XfVGrrfSH", b"\xE1\x49\x32\xE4\xFC\x79\x48\x18\x95\x40\xA4\x60\xBC\x2D\x11\xB4",
      4, "$2b$04$2Siw3Nv3Q/gTOIPetAyPr.GNj3aO0lb1E5E9UumYGKjP9BYqlNWJe",
    ),
    (
      b"cTT0EAFdwJiLn", b"\xF4\x14\xA5\xF4\xC7\xFE\x0D\xE5\x1C\x8D\x14\x3A\x9A\x30\xFE\xA2",
      4, "$2b$04$7/Qj7Kd8BcSahPO4khB8me4ssDJCW3r4OGYqPF87jxtrSyPj5cS5m",
    ),
    (
      b"J8eHUDuxBB520", b"\x5F\x19\xC4\x58\xC7\x55\x3A\x57\x33\x71\xA2\xC0\x9B\xB9\x70\xAA",
      4, "$2b$04$VvlCUKbTMjaxaYJ.k5juoecpG/7IzcH1AkmqKi.lIZMVIOLClWAk.",
    ),
    (
      b"}>\xB3\xFE\xF1\x8B\xA0\xE6(\xA2Lzq\xC3P\x7F\xCC\xC8b{\xF9\x14\xF6\xF6`\x81G5\xEC\x1D\x87\x10\xBF\xA7\xE1}I7 \x96\xDFc\xF2\xBF\xB3Vh\xDFM\x88q\xF7\xFF\x1B\x82~z\x13\xDD\xE9\x84\x00\xDD4",
      b"\x9A\x04\x00\x6D\xBB\xB8\xE1\xAB\xF4\x89\x71\xFC\x0C\xD8\x63\x21", 10, "$2b$10$keO.ZZs22YtygVF6BLfhGOI/JjshJYPp8DZsUtym6mJV2Eha2Hdd.",
    ),
  ]
  for index, vector in vectors {
    let (password, salt, cost, expected) = vector
    assert_eq(
      @bcrypt.hash_password(password, salt, cost),
      Ok(expected),
      msg="pyca hash vector \{index + 1}",
    )
    assert_eq(
      @bcrypt.verify(password, expected),
      Ok(true),
      msg="pyca verify vector \{index + 1}",
    )
  }
}

///|
test "pyca bcrypt NUL bytes in passwords" {
  // Fixed salt from the first reference vector: cVWp4XaNU8a4v1uMRum2SO.
  let salt = b"\x79\x76\x2B\xE9\x97\x0F\x5B\xE7\x3A\xC7\x7C\x0E\x4F\x0A\x38\x51"
  let hash = @bcrypt.hash_password(b"abc\x00def", salt, 4).unwrap()
  assert_eq(@bcrypt.verify(b"abc\x00def", hash), Ok(true))
  // Bytes after the first NUL, including trailing NULs, affect the password.
  let different_passwords : Array[Bytes] = [
    b"abc", b"abcdef", b"abc\x00deg", b"abc\x00def\x00", b"abc\x00def\x00\x00",
  ]
  for index, password in different_passwords {
    assert_eq(
      @bcrypt.verify(password, hash),
      Ok(false),
      msg="pyca NUL mismatch \{index + 1}",
    )
  }
}
