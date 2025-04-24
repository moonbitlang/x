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

///|
fn internal_get_cli_args() -> FixedArray[Bytes] = "$moonbit.get_cli_args"

///|
fn get_cli_args_internal() -> Array[String] {
  Array::from_fixed_array(
    internal_get_cli_args().map(fn {
      // Here we assume that the CLI arguments are encoded in well-formed UTF-8.
      // TODO: Handle other encodings.
      arg => @ffi.utf8_bytes_to_mbt_string(arg)
    }),
  )
}

///|
fn get_env_vars_internal() -> Map[String, String] {
  let env_vars = get_env_vars_ffi().map(fn {
    env => @ffi.utf8_bytes_to_mbt_string(env)
  })
  let res = {}
  for i = 0; i < env_vars.length(); i = i + 2 {
    res[env_vars[i]] = env_vars[i + 1]
  }
  res
}

///|
extern "C" fn get_env_vars_ffi() -> FixedArray[Bytes] = "get_env_vars"

///|
fn set_env_var_internal(key : String, value : String) -> Unit {
  set_env_var_ffi(
    @ffi.mbt_string_to_utf8_bytes(key, true),
    @ffi.mbt_string_to_utf8_bytes(value, true),
  )
}

///|
extern "C" fn set_env_var_ffi(_key : Bytes, _value : Bytes) -> Unit = "set_env_var"

///|
fn unset_env_var_internal(key : String) -> Unit {
  unset_env_var_ffi(@ffi.mbt_string_to_utf8_bytes(key, true))
}

///|
extern "C" fn unset_env_var_ffi(_key : Bytes) -> Unit = "unset_env_var"

///|
extern "C" fn exit_internal(code : Int) -> Unit = "exit"
