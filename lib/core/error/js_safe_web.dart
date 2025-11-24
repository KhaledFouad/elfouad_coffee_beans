// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// ignore: uri_does_not_exist
import 'dart:js_util' as js_util;

Object? getJsProp(Object target, String prop) {
  try {
    return js_util.hasProperty(target, prop)
        ? js_util.getProperty(target, prop)
        : null;
  } catch (_) {
    return null;
  }
}
