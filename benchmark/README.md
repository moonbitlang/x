# moonbitlang/x/benchmark

⚠️Please note that this benchmark is a very temporary implementation and the credibility of the results may be low. Due to the lack of coordination in building the system, we need to measure the time twice (once for calculating Average Time and once for calculating the maximum and minimum values of a single measurement), so there may be situations where the average time is greater than the maximum time

In the future, we will try more effective methods to benchmark

## Overview

This section provides some benchmark APIs, which are unstable and may be removed or modified at any time.

## Usage

You can create Criterion and add tasks(by `add` and `Task::new`) to them like this:

```moonbit
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

let criterion = Criterion::new()
criterion.add(Task::new("sum", fn() { sum(10000000) |> ignore }, count=100))
```

You need to specify a name and a function to test for each task, with an optional parameter being the number of times it will be executed. In statistical experience, the higher the number of times, the more accurate the results will be, and the default value for the number of times is 10.

Next, you can run these tests：

```moonbit
let result=criterion.run()
println(result["sum"])
```

The return type is Map[String, TaskResult], which indexes the results of each run by name. Additionally, TaskResult implements the show trait, so it can be directly output.

The following is a detailed definition of Task/TaskResult:

```moonbit
struct Task {
  name : String // The name of the task
  f : () -> Unit // The tested function
  count : Int // Number of tests conducted
}

struct TaskResult {
  task : Task // Task corresponding to the result
  average : Double // Average execution time
  max : Double // Maximum execution time per execution
  min : Double // Minimum execution time per execution
}
```
