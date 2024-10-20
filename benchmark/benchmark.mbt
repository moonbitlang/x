type Instant

fn instant_now() -> Instant = "__moonbit_time_unstable" "instant_now"

fn instant_elapsed_as_secs_f64(x : Instant) -> Double = "__moonbit_time_unstable" "instant_elapsed_as_secs_f64"

struct Task {
  name : String
  f : () -> Unit
  count : Int
}

struct TaskResult {
  task : Task
  average : Double
  max : Double
  min : Double
}

pub fn Task::new(name : String, f : () -> Unit, ~count : Int = 10) -> Task {
  { name, f, count }
}

pub fn run(self : Task) -> TaskResult {
  let now = instant_now()
  for i = 1; i <= self.count; i = i + 1 {
    (self.f)()
  }
  let time = instant_elapsed_as_secs_f64(now)
  let mut max : Double = @double.min_value
  let mut min : Double = @double.max_value
  for i = 1; i <= self.count; i = i + 1 {
    let per_now = instant_now()
    (self.f)()
    let pre_time = instant_elapsed_as_secs_f64(per_now)
    max = @math.maximum(max, pre_time)
    min = @math.minimum(min, pre_time)
  }
  { task: self, average: time / self.count.to_double(), max, min }
}

pub fn to_string(self : TaskResult) -> String {
  $|Benchmark Task [\{self.task.name}] Count = \{self.task.count}
  $|----------------------------------------
  $|Average Time: \{self.average}s/per test
  $|Max Time Per Test: \{self.max}s/per test
  $|Min Time Per Test: \{self.min}s/per test
  $|----------------------------------------
}

pub fn output(self : TaskResult, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub struct Criterion {
  tasks : Array[Task]
}

pub fn Criterion::new() -> Criterion {
  { tasks: [] }
}

pub fn add(self : Criterion, task : Task) -> Unit {
  self.tasks.push(task)
}

pub fn run(self : Criterion) -> Map[String, TaskResult] {
  let map = {}
  for task in self.tasks {
    map[task.name] = task.run()
  }
  map
}

fn sum(x : Int) -> Int {
  let mut result = 0
  for i = 1; i <= x; i = i + 1 {
    result += x
    result %= 11451419
    result -= 2
    result = result | 1
    result *= 19190
    result %= 11451419
  }
  result
}

test "bm_sum" {
  let criterion = Criterion::new()
  criterion.add(Task::new("sum", fn() { sum(10000000) |> ignore }, count=100))
  println(criterion.run()["sum"])
}
