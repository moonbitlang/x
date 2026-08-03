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
/// Gets the command line arguments passed to the program.
///
/// This function returns `argv[0]` as the name of the program, and the rest are
/// the other arguments passed to the program (C-style `argv` list). This list
/// of arguments does not contain the runtime used to run the program, nor any
/// arguments meant to be consumed by the runtime.
///
/// Use `@env.args()` from `moonbitlang/core/env` instead. On the JavaScript
/// backend, `@env.args()` returns `process.argv` unchanged, while this function
/// omits `process.argv[0]`, the JavaScript runtime executable. The program name
/// and user arguments therefore shift by one index after migration.
#cfg(not(target="js"))
#deprecated("Use `@env.args()` from `moonbitlang/core/env` instead. On the JavaScript backend, `@env.args()` returns `process.argv` unchanged, while this function omits `process.argv[0]`, the JavaScript runtime executable.")
pub fn get_cli_args() -> Array[String] {
  @env.args()
}

///|
/// Gets the command line arguments passed to the program.
///
/// This function returns `argv[0]` as the name of the program, and the rest are
/// the other arguments passed to the program (C-style `argv` list). This list
/// of arguments does not contain the runtime used to run the program, nor any
/// arguments meant to be consumed by the runtime.
///
/// Use `@env.args()` from `moonbitlang/core/env` instead. On the JavaScript
/// backend, `@env.args()` returns `process.argv` unchanged, while this function
/// omits `process.argv[0]`, the JavaScript runtime executable. The program name
/// and user arguments therefore shift by one index after migration.
#cfg(target="js")
#deprecated("Use `@env.args()` from `moonbitlang/core/env` instead. On the JavaScript backend, `@env.args()` returns `process.argv` unchanged, while this function omits `process.argv[0]`, the JavaScript runtime executable.")
pub fn get_cli_args() -> Array[String] {
  let args = @env.args()
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
/// Gets the environment variables of the current process.
#deprecated("Use `@env.get_env_vars()` from `moonbitlang/core/env` instead.")
pub fn get_env_vars() -> Map[String, String] {
  @env.get_env_vars()
}

///|
/// Gets the environment variable of specific key of the current process.
/// If the environment variable is not set or exists, returns `None`.
#deprecated("Use `@env.get_env_var()` from `moonbitlang/core/env` instead.")
pub fn get_env_var(key : String) -> String? {
  @env.get_env_var(key)
}

///|
/// Sets an environment variable.
#deprecated("Use `@env.set_env_var()` from `moonbitlang/core/env` instead.")
pub fn set_env_var(key : String, value : String) -> Unit {
  @env.set_env_var(key, value)
}

///|
/// Unsets an environment variable.
#deprecated("Use `@env.unset_env_var()` from `moonbitlang/core/env` instead.")
pub fn unset_env_var(key : String) -> Unit {
  @env.unset_env_var(key)
}

///|
/// Exits the program immediately with the given exit code.
pub fn exit(code : Int) -> Unit {
  @ffi.exit(code)
}
