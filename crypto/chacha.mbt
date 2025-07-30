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
fn flipWord(word : UInt) -> UInt {
  let b0 = (word & 0xff) << 24
  let b1 = (word & 0xff00) << 8
  let b2 = (word & 0xff0000) >> 8
  let b3 = (word & 0xff000000) >> 24
  b0 | b1 | b2 | b3
}

///|
test "flipWord" {
  let word = 0x12345678U
  let flipped = flipWord(word)
  inspect(flipped, content="2018915346")
}

///|
fn FixedArray::quarterRound(
  state : FixedArray[UInt],
  w : Int,
  x : Int,
  y : Int,
  z : Int,
) -> Unit {
  fn fullQuarterRound(
    a : UInt,
    b : UInt,
    c : UInt,
    d : UInt,
  ) -> (UInt, UInt, UInt, UInt) {
    (a, b, c, d)
    |> quarterRound1
    |> quarterRound2
    |> quarterRound3
    |> quarterRound4
  }

  let t = fullQuarterRound(state[w], state[x], state[y], state[z])
  state[w] = t.0
  state[x] = t.1
  state[y] = t.2
  state[z] = t.3
}

///|
test "quarterRound" {
  let state = FixedArray::make(16, 0U)
  state[0] = 0x879531e0U
  state[1] = 0xc5ecf37dU
  state[2] = 0x516461b1U
  state[3] = 0xc9a62f8aU
  state[4] = 0x44c20ef3U
  state[5] = 0x3390af7fU
  state[6] = 0xd9fc690bU
  state[7] = 0x2a5f714cU
  state[8] = 0x53372767U
  state[9] = 0xb00a5631U
  state[10] = 0x974c541aU
  state[11] = 0x359e9963U
  state[12] = 0x5c971061U
  state[13] = 0x3d631689U
  state[14] = 0x2098d9d6U
  state[15] = 0x91dbd320U
  state.quarterRound(2, 7, 8, 13)
  inspect(
    state,
    content="[2274701792, 3320640381, 3182986972, 3383111562, 1153568499, 865120127, 3657197835, 3484200914, 3832277632, 2953467441, 2538361882, 899586403, 1553404001, 3435166841, 546888150, 2447102752]",
  )
}

///|
fn FixedArray::chachaBlockRound(state : FixedArray[UInt]) -> Unit {
  state
  ..quarterRound(0, 4, 8, 12)
  ..quarterRound(1, 5, 9, 13)
  ..quarterRound(2, 6, 10, 14)
  ..quarterRound(3, 7, 11, 15)
  ..quarterRound(0, 5, 10, 15)
  ..quarterRound(1, 6, 11, 12)
  ..quarterRound(2, 7, 8, 13)
  ..quarterRound(3, 4, 9, 14)
}

///|
test "chachaBlockRound" {
  let state = FixedArray::make(16, 0U)
  state[0] = 0x61707865U
  state[1] = 0x3320646eU
  state[2] = 0x79622d32U
  state[3] = 0x6b206574U
  state[4] = 0x03020100U
  state[5] = 0x07060504U
  state[6] = 0x0b0a0908U
  state[7] = 0x0f0e0d0cU
  state[8] = 0x13121110U
  state[9] = 0x17161514U
  state[10] = 0x1b1a1918U
  state[11] = 0x1f1e1d1cU
  state[12] = 0x00000001U
  state[13] = 0x00000000U
  state[14] = 0x00000000U
  state[15] = 0x00000000U
  state.chachaBlockRound()
  inspect(
    state,
    content="[986087425, 3489031050, 2890662805, 2683391196, 1720476390, 1116253759, 2262580386, 3212003942, 2202368212, 756352536, 496298475, 669838588, 567302638, 1860562437, 1434237441, 2097484794]",
  )
}

///|
fn FixedArray::chachaBlockLoop(state : FixedArray[UInt], n : UInt) -> Unit {
  for i in 0U..<n {
    state.chachaBlockRound()
  }
}

///|
test "chachaBlockLoop" {
  let count = 1U
  let key = FixedArray::make(8, 0U)
  key[0] = 0x00010203U
  key[1] = 0x04050607U
  key[2] = 0x08090a0bU
  key[3] = 0x0c0d0e0fU
  key[4] = 0x10111213U
  key[5] = 0x14151617U
  key[6] = 0x18191a1bU
  key[7] = 0x1c1d1e1fU
  let state = FixedArray::make(16, 0U)
  state[0] = 0X61707865U
  state[1] = 0X3320646eU
  state[2] = 0X79622d32U
  state[3] = 0X6b206574U
  state[4] = flipWord(key[0])
  state[5] = flipWord(key[1])
  state[6] = flipWord(key[2])
  state[7] = flipWord(key[3])
  state[8] = flipWord(key[4])
  state[9] = flipWord(key[5])
  state[10] = flipWord(key[6])
  state[11] = flipWord(key[7])
  state[12] = count
  state[13] = 0
  state[14] = 0
  state[15] = 0
  inspect(
    state,
    content="[1634760805, 857760878, 2036477234, 1797285236, 50462976, 117835012, 185207048, 252579084, 319951120, 387323156, 454695192, 522067228, 1, 0, 0, 0]",
  )
  state.chachaBlockLoop(4)
  inspect(
    state,
    content="[2919080465, 647515738, 898727107, 777299107, 3407982512, 2489307765, 745530666, 2053399858, 1994399329, 139328223, 3709168053, 3118545354, 4170274417, 867477305, 1393604261, 3769539545]",
  )
}

///|
fn zipWith(
  op : (UInt, UInt) -> UInt,
  state1 : FixedArray[UInt],
  state2 : FixedArray[UInt],
) -> FixedArray[UInt] {
  let result = FixedArray::make(state1.length(), 0U)
  for i = 0; i < state1.length(); i = i + 1 {
    result[i] = op(state1[i], state2[i])
  }
  result
}

///|
test "zipWith" {
  let state1 = FixedArray::make(4, 0U)
  state1[0] = 1
  state1[1] = 2
  state1[2] = 3
  state1[3] = 4
  let state2 = FixedArray::make(4, 0U)
  state2[0] = 5
  state2[1] = 6
  state2[2] = 7
  state2[3] = 8
  let result = zipWith(UInt::op_add, state1, state2)
  inspect(result, content="[6, 8, 10, 12]")
}

///| - chacha8: round = 4
/// - chacha12: round = 6
/// - chacha20: round = 10
fn chachaBlock(
  key : FixedArray[UInt],
  count : UInt,
  nonce : UInt,
  round : UInt,
) -> FixedArray[UInt] {
  if key.length() != 8 {
    abort("Invalid key length -- key must be 256 bits")
  }
  let state = FixedArray::make(16, 0U)
  state[0] = 0X61707865U
  state[1] = 0X3320646eU
  state[2] = 0X79622d32U
  state[3] = 0X6b206574U
  state[4] = flipWord(key[0])
  state[5] = flipWord(key[1])
  state[6] = flipWord(key[2])
  state[7] = flipWord(key[3])
  state[8] = flipWord(key[4])
  state[9] = flipWord(key[5])
  state[10] = flipWord(key[6])
  state[11] = flipWord(key[7])
  state[12] = count
  state[13] = nonce
  state[14] = nonce
  state[15] = nonce
  let mixedState = state.copy()
  mixedState.chachaBlockLoop(round)
  for i in 0..<16 {
    mixedState[i] = flipWord(mixedState[i] + state[i])
  }
  mixedState
}

///|
test "chachaBlock" {
  let key = FixedArray::make(8, 0U)
  key[0] = 0x00010203U
  key[1] = 0x04050607U
  key[2] = 0x08090a0bU
  key[3] = 0x0c0d0e0fU
  key[4] = 0x10111213U
  key[5] = 0x14151617U
  key[6] = 0x18191a1bU
  key[7] = 0x1c1d1e1fU
  let keyStream = chachaBlock(key, 1, 0, 4)
  inspect(
    keyStream,
    content="[1981443599, 3367155801, 4121555886, 386561433, 2964333518, 2044159387, 854489399, 1047687817, 1898967689, 4077872159, 3447861240, 3864461272, 1918276088, 967291955, 2780172371, 3650858720]",
  )
}

///|
fn stateToBytes(state : FixedArray[UInt]) -> FixedArray[Byte] {
  fn from_array(arr : Array[UInt]) -> FixedArray[Byte] {
    let rv = FixedArray::make(arr.length(), Byte::default())
    for i = 0; i < arr.length(); i = i + 1 {
      rv[i] = arr[i].to_byte()
    }
    rv
  }

  let result = Array::make(64, 0U)
  for i = 0; i < 16; i = i + 1 {
    let word = state[i]
    result[i * 4 + 3] = word & 0xff
    result[i * 4 + 2] = (word & 0xff00) >> 8
    result[i * 4 + 1] = (word & 0xff0000) >> 16
    result[i * 4 + 0] = (word & 0xff000000) >> 24
  }
  from_array(result)
}

///|
test "stateToBytes" {
  let state = FixedArray::make(16, 0U)
  state[0] = 0x879531e0
  state[1] = 0xc5ecf37d
  state[2] = 0x516461b1
  state[3] = 0xc9a62f8a
  state[4] = 0x44c20ef3
  state[5] = 0x3390af7f
  state[6] = 0xd9fc690b
  state[7] = 0x2a5f714c
  state[8] = 0x53372767
  state[9] = 0xb00a5631
  state[10] = 0x974c541a
  state[11] = 0x359e9963
  state[12] = 0x5c971061
  state[13] = 0x3d631689
  state[14] = 0x2098d9d6
  state[15] = 0x91dbd320
  let bytes = stateToBytes(state)
  inspect(
    bytes_to_hex_string(bytes),
    content="879531e0c5ecf37d516461b1c9a62f8a44c20ef33390af7fd9fc690b2a5f714c53372767b00a5631974c541a359e99635c9710613d6316892098d9d691dbd320",
  )
}

///| Encrypts a block of data using the ChaCha8 algorithm.
/// - [key] must be 8 32-bit unsigned integers.
/// - [counter] is the counter value.
/// - [block] is the block of data to be encrypted.
/// - [nonce] is default to 0
/// - Returns the encrypted block of data.
pub fn[Data : ByteSource] chacha8(
  key : FixedArray[UInt],
  counter : UInt,
  block : Data,
  nonce~ : UInt = 0,
) -> FixedArray[Byte] raise Error {
  if key.length() != 8 {
    fail("Invalid key length -- key must be 8 32-bit unsigned integers")
  }
  chacha(key, counter, block, 4, nonce)
}

///| Encrypts a block of data using the ChaCha12 algorithm.
/// - [key] must be 8 32-bit unsigned integers.
/// - [counter] is the counter value.
/// - [block] is the block of data to be encrypted.
/// - [nonce] is default to 0
/// - Returns the encrypted block of data.
pub fn[Data : ByteSource] chacha12(
  key : FixedArray[UInt],
  counter : UInt,
  block : Data,
  nonce~ : UInt = 0,
) -> FixedArray[Byte] raise Error {
  if key.length() != 8 {
    fail("Invalid key length -- key must be 8 32-bit unsigned integers")
  }
  chacha(key, counter, block, 6, nonce)
}

///| Encrypts a block of data using the ChaCha20 algorithm.
/// - [key] must be 8 32-bit unsigned integers.
/// - [counter] is the counter value.
/// - [block] is the block of data to be encrypted.
/// - [nonce] is default to 0
/// - Returns the encrypted block of data.
pub fn[Data : ByteSource] chacha20(
  key : FixedArray[UInt],
  counter : UInt,
  block : Data,
  nonce~ : UInt = 0,
) -> FixedArray[Byte] raise Error {
  if key.length() != 8 {
    fail("Invalid key length -- key must be 8 32-bit unsigned integers")
  }
  chacha(key, counter, block, 10, nonce)
}

///|
fn[Data : ByteSource] chacha(
  key : FixedArray[UInt],
  counter : UInt,
  block : Data,
  round : UInt,
  nonce : UInt,
) -> FixedArray[Byte] {
  if block.length() == 0 {
    return FixedArray::make(0, Byte::default())
  }
  fn takeToFixedArray(b : &ByteSource, len : Int) -> FixedArray[Byte] {
    let result = FixedArray::make(len, Byte::default())
    b.blit_to(result, len~, src_offset=0, dst_offset=0)
    result
  }

  fn zipWith(
    op : (Byte, Byte) -> Byte,
    state1 : FixedArray[Byte],
    state2 : FixedArray[Byte],
  ) -> FixedArray[Byte] {
    let result = FixedArray::make(state1.length(), Byte::default())
    for i = 0; i < state1.length(); i = i + 1 {
      result[i] = op(state1[i], state2[i])
    }
    result
  }

  fn dropBytes(b : &ByteSource, len : Int) -> FixedArray[Byte] {
    let result = FixedArray::make(b.length() - len, Byte::default())
    b.blit_to(result, len=b.length() - len, src_offset=len, dst_offset=0)
    result
  }

  fn concatBytes(
    b1 : FixedArray[Byte],
    b2 : FixedArray[Byte],
  ) -> FixedArray[Byte] {
    let result = FixedArray::make(b1.length() + b2.length(), Byte::default())
    for i = 0; i < b1.length(); i = i + 1 {
      result[i] = b1[i]
    }
    for i = 0; i < b2.length(); i = i + 1 {
      result[b1.length() + i] = b2[i]
    }
    result
  }

  let keyStream = chachaBlock(key, counter, nonce, round)
  let pad = stateToBytes(keyStream)
  let len = if block.length() < 64 { block.length() } else { 64 }
  let maskedBlock = zipWith(
    Byte::lxor,
    takeToFixedArray(pad, len),
    takeToFixedArray(block, len),
  )
  let res = concatBytes(
    maskedBlock,
    chacha(key, counter + 1, dropBytes(block, len), round, nonce),
  )
  res
}

///|
fn quarterRound1(t : (UInt, UInt, UInt, UInt)) -> (UInt, UInt, UInt, UInt) {
  let aprime = t.0 + t.1
  let dprime = t.3 ^ aprime
  let dout = rotate_left_u(dprime, 16)
  (aprime, t.1, t.2, dout)
}

///|
fn quarterRound2(t : (UInt, UInt, UInt, UInt)) -> (UInt, UInt, UInt, UInt) {
  let cprime = t.2 + t.3
  let bprime = t.1 ^ cprime
  let bout = rotate_left_u(bprime, 12)
  (t.0, bout, cprime, t.3)
}

///|
fn quarterRound3(t : (UInt, UInt, UInt, UInt)) -> (UInt, UInt, UInt, UInt) {
  let aprime = t.0 + t.1
  let dprime = t.3 ^ aprime
  let dout = rotate_left_u(dprime, 8)
  (aprime, t.1, t.2, dout)
}

///|
fn quarterRound4(t : (UInt, UInt, UInt, UInt)) -> (UInt, UInt, UInt, UInt) {
  let cprime = t.2 + t.3
  let bprime = t.1 ^ cprime
  let bout = rotate_left_u(bprime, 7)
  (t.0, bout, cprime, t.3)
}
