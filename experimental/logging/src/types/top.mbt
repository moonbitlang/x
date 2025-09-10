///|
/// Logging Level
/// 
/// Defined based on RFC 5424 standard.
pub(all) enum Level {
  Debug
  Info
  Notice
  Warning
  Error
  Critical
  Alert
  Emergency
} derive(Eq, Show, Compare, Hash)
