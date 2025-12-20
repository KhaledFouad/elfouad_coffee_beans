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

List<String> getJsKeys(Object target) {
  try {
    final keys = js_util.objectKeys(target);
    return List<String>.from(keys);
  } catch (_) {
    return const [];
  }
}

String? jsStringify(Object target) {
  try {
    final json = js_util.getProperty(js_util.globalThis, 'JSON');
    final out = js_util.callMethod(json, 'stringify', [target]);
    return out?.toString();
  } catch (_) {
    return null;
  }
}
