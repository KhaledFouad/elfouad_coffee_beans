import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// استيراد مشروط: على الويب نقرأ خصائص JS، وعلى الموبايل نرجّع null
import 'js_safe_stub.dart' if (dart.library.js) 'js_safe_web.dart';

/// رسالة خطأ ودّية جاهزة للعرض
String prettyError(Object error, [StackTrace? st]) {
  // أخطاءك الودّية
  if (error is Exception && error.runtimeType.toString() == 'UserFriendly') {
    // لو عندك كلاس UserFriendly في ملفات أخرى (بنفس الاسم)
    try {
      final msg = (error as dynamic).message?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg;
    } catch (_) {}
  }

  if (error is FirebaseException) {
    final code = error.code.isNotEmpty ? ' (${error.code})' : '';
    final msg = error.message ?? 'خطأ من Firebase';
    return '$msg$code';
  }

  if (error is FormatException) return error.message;
  if (error is AssertionError) {
    return error.message?.toString() ?? 'Assertion error';
  }

  // على الويب: جرّب تقرأ خصائص message/code إن كانت جايّة من JS
  if (kIsWeb) {
    final m = getJsProp(error, 'message')?.toString();
    final c = getJsProp(error, 'code')?.toString();
    if ((m != null && m.isNotEmpty) || (c != null && c.isNotEmpty)) {
      return [m, c].where((e) => e != null && e.isNotEmpty).join(' • ');
    }
  }

  // fallback
  final s = error.toString();
  if (s == 'Instance of \'FirebaseException\'' && kIsWeb) {
    return 'حدث خطأ غير متوقع.';
  }
  return s;
}

/// دialog موحّد لعرض الأخطاء
Future<void> showErrorDialog(
  BuildContext context,
  Object error, [
  StackTrace? st,
]) {
  final msg = prettyError(error, st);
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تعذر إتمام العملية'),
      content: SingleChildScrollView(child: Text(msg)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

/// لوج خفيف وقت التطوير
void logError(Object e, [StackTrace? st]) {
  // تجاهل في الإصدار النهائي لو حابب
  debugPrint('❗ ERROR: $e');
  if (st != null) debugPrint('STACK:\n$st');
}
