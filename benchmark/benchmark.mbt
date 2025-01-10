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
pub fn Task::new(name : String, f : () -> Unit, count~ : Int = 10) -> Task {
  { name, f, count }
}

///|
pub fn run(self : Task) -> TaskResult {
  let now = @ffi.instant_now()
  for i = 1; i <= self.count; i = i + 1 {
    (self.f)()
  }
  let time = @ffi.instant_elapsed_as_secs_f64(now)
  let mut max = @double.min_value
  let mut min = @double.max_value
  for i = 1; i <= self.count; i = i + 1 {
    let per_now = @ffi.instant_now()
    (self.f)()
    let pre_time = @ffi.instant_elapsed_as_secs_f64(per_now)
    max = @math.maximum(max, pre_time)
    min = @math.minimum(min, pre_time)
  }
  { task: self, average: time / self.count.to_double(), max, min }
}

///|
pub fn to_string(self : TaskResult) -> String {
  $|Benchmark Task [\{self.task.name}] Count = \{self.task.count}
  $|----------------------------------------
  $|Average Time: \{self.average}s/per test
  $|Max Time Per Test: \{self.max}s/per test
  $|Min Time Per Test: \{self.min}s/per test
  $|----------------------------------------
}

///|
pub fn output(self : TaskResult, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn Criterion::new() -> Criterion {
  { tasks: [] }
}

///|
pub fn add(self : Criterion, task : Task) -> Unit {
  self.tasks.push(task)
}

///|
pub fn Criterion::run(self : Criterion) -> Map[String, TaskResult] {
  let map = {}
  for task in self.tasks {
    map[task.name] = task.run()
  }
  map
}
