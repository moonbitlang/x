// Copyright 2024 International Digital Economy Academy
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

test "chachaEncrypt" {
  let key = FixedArray::make(8, 0U)
  key[0] = 0
  key[1] = 0
  key[2] = 0
  key[3] = 0
  key[4] = 0
  key[5] = 0
  key[6] = 0
  key[7] = 0
  let plaintext = "abc"
  let block = plaintext.to_bytes()
  inspect!(bytes_to_hex_string(block), content="610062006300")
  let encrypted = @crypto.chacha8(key, 0, block)
  let expected = "5f008d2fea5f"
  @test.eq!(bytes_to_hex_string(encrypted), expected)
  let encrypted = @crypto.chahca12(key, 0, block)
  let expected = "faf4f86a6455"
  @test.eq!(bytes_to_hex_string(encrypted), expected)
  let encrypted = @crypto.chacha20(key, 0, block)
  let expected = "17b882adc3f1"
  @test.eq!(bytes_to_hex_string(encrypted), expected)
}
