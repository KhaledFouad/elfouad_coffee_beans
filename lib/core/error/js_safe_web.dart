// هذا الملف لن يُستورد إلا على الويب بفضل الشرط if (dart.library.js)
import 'dart:js_util' as js_util;

Object? getJsProp(Object o, String prop) {
  try {
    return js_util.hasProperty(o, prop) ? js_util.getProperty(o, prop) : null;
  } catch (_) {
    return null;
  }
}
