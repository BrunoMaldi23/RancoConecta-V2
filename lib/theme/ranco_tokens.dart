abstract final class RancoSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class RancoRadius {
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

abstract final class RancoBreakpoints {
  static const compact = 0.0;
  static const medium = 600.0;
  static const expanded = 1024.0;
  static const large = 1440.0;

  static bool isCompact(double width) => width < medium;
  static bool isMedium(double width) => width >= medium && width < expanded;
  static bool isExpanded(double width) => width >= expanded && width < large;
  static bool isLarge(double width) => width >= large;
}

abstract final class RancoDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}
