type Date

pub extern "js" fn instant_now() -> Date =
  #| () => new Date()

pub extern "js" fn instant_elapsed_as_secs_f64(x : Date) -> Double =
  #|function cost(x){
  #|  const now = new Date();
  #|  return (now.getTime() - x.getTime())/1000;
  #|}
