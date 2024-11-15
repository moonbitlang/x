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

typealias XExternStringArray = @ffi.XExternStringArray

pub fn get_cli_args() -> Array[String] {
  let args = get_cli_args_ffi()
  @ffi.string_array_from_extern(args)
}

fn get_cli_args_ffi() -> XExternStringArray = "__moonbit_fs_unstable" "args_get"

pub fn get_env_var() -> Map[String, String] {
  let env = get_env_var_ffi()
  let tmp = @ffi.string_array_from_extern(env)
  let res = {}
  for i = 0; i < tmp.length(); i = i + 2 {
    res[tmp[i]] = tmp[i + 1]
  }
  res
}

fn get_env_var_ffi() -> XExternStringArray = "__moonbit_fs_unstable" "env_get_vars"
