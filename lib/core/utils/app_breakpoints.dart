import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AppBreakpoints {
  static const double compactWidth = 900;
  static const double desktopWidth = 1200;
  static const double wideWidth = 1600;
  static const int tabletStart = 600;
  static const int tabletEnd = 899;

  static final List<Breakpoint> values = [
    const Breakpoint(start: 0, end: 599, name: MOBILE),
    const Breakpoint(start: 600, end: 899, name: TABLET),
    const Breakpoint(start: 900, end: 1199, name: DESKTOP),
    const Breakpoint(start: 1200, end: 1799, name: 'XL'),
    const Breakpoint(start: 1800, end: double.infinity, name: '4K'),
  ];

  static bool isCompact(double width) => width < compactWidth;
  static bool isDesktop(double width) => width >= desktopWidth;
  static bool isWide(double width) => width >= wideWidth;

  static int gridCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  static EdgeInsets gridPagePadding(double width) {
    final horizontal = width < 600 ? 12.0 : 16.0;
    final top = width < 600 ? 16.0 : 20.0;
    final bottom = width < 600 ? 12.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}
