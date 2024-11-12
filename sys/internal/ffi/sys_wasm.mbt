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

typealias XExternString = @ffi.XExternString

typealias XExternStringArray = @ffi.XExternStringArray

pub fn get_cli_args() -> Array[String] {
  let args = get_cli_args_ffi()
  @ffi.string_array_from_extern(args)
}

fn get_cli_args_ffi() -> XExternStringArray = "__moonbit_fs_unstable" "args_get"

pub fn get_env_var(s : String) -> String {
  let s = @ffi.string_to_extern(s)
  let res = get_env_var_ffi(s)
  @ffi.string_from_extern(res)
}

fn get_env_var_ffi(s : XExternString) -> XExternString = "__moonbit_fs_unstable" "env_get_var"
