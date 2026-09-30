/// The first line of [error], bounded to [max] characters.
///
/// Provider exceptions embed every nested cause and stack trace — over 100k
/// characters — and rendering that raw overflows any screen. The UI states
/// what failed; it does not dump the trace.
String briefErrorLabel(Object error, {int max = 200}) {
  final firstLine = error.toString().split('\n').first;
  return firstLine.length > max ? '${firstLine.substring(0, max)}…' : firstLine;
}
