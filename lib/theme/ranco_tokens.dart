abstract final class RancoSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class RancoRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}

abstract final class RancoBreakpoints {
  static const compact = 0.0;
  static const medium = 600.0;
  static const expanded = 840.0;
  static const large = 1200.0;
}

abstract final class RancoDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}
