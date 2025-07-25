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
#deprecated("use `@stack.from_iter(list.iter())` instead")
#coverage.skip
pub fn[T] Stack::from_list(list : @immut/list.T[T]) -> Stack[T] {
  { elements: @list.from_iter(list.iter()), len: list.length() }
}

///| Push a list into the stack.
/// 
/// # Example
///
/// ```
///   let s = @stack.new()
///   @immut/list.of([1, 2, 3]).each(s.push(_))
///   assert_eq(s.length(), 3)
/// ```
#deprecated("use `list.each(stack.push(_)` instead")
#coverage.skip
pub fn[T] push_list(self : Stack[T], list : @immut/list.T[T]) -> Unit {
  list.each(fn(i) { self.push(i) })
}

///| Convert stack to list.
///
/// # Example
///
/// ```
///   assert_eq(@stack.of([1, 2, 3]).to_list(), @immut/list.of([1, 2, 3]))
/// ```
#deprecated("Use `stack.iter() |> @immut/list.from_iter()` instead")
pub fn[T] to_list(self : Stack[T]) -> @immut/list.T[T] {
  self.elements.iter() |> @immut/list.from_iter()
}

///|
#deprecated("Use `unsafe_peek` instead")
pub fn[T] peek_exn(self : Stack[T]) -> T {
  self.elements.unsafe_head()
}
