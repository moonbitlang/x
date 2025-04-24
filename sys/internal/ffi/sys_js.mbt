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
extern "js" fn get_cli_args_internal() -> Array[String] =
  #| function() {
  #|  return process.argv.slice(1);  // node has argv[0] as the node executable
  #| }

///|
fn get_env_vars_internal() -> Map[String, String] {
  let tmp = get_env_vars_js()
  let res = {}
  for i = 0; i < tmp.length(); i = i + 2 {
    res[tmp[i]] = tmp[i + 1]
  }
  res
}

///|
extern "js" fn get_env_vars_js() -> Array[String] =
  #| function() {
  #|   const env = process.env;
  #|   const result = [];
  #|   for (const key in env) {
  #|     result.push(key);
  #|     result.push(env[key]);
  #|   }
  #|   return result;
  #| }

///|
fn set_env_var_internal(key : String, value : String) -> Unit {
  set_env_var_js(key, value)
}

///|
extern "js" fn set_env_var_js(key : String, value : String) -> Unit =
  #| function(key, value) {
  #|   process.env[key] = value;
  #| }

///|
fn unset_env_var_internal(key : String) -> Unit {
  unset_env_var_js(key)
}

///|
extern "js" fn unset_env_var_js(key : String) -> Unit =
  #| function(key) {
  #|   delete process.env[key];
  #| }

///|
extern "js" fn exit_internal(code : Int) -> Unit =
  #| function(code) {
  #|   process.exit(code);
  #| }
