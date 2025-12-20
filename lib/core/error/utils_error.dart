import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_coffee_beans/core/utils/app_strings.dart';

// استيراد مشروط: على الويب نقرأ خصائص JS، وعلى الموبايل نرجّع null
import 'js_safe_stub.dart' if (dart.library.js) 'js_safe_web.dart';

String? _firstStackLine(String? stack) {
  if (stack == null || stack.isEmpty) return null;
  for (final line in stack.split('\n')) {
    final cleaned = line.trim();
    if (cleaned.isNotEmpty) return cleaned;
  }
  return null;
}

String? _bestJsMessage(Object? error, {String? skip}) {
  if (error == null) return null;
  final name = getJsProp(error, 'name')?.toString();
  final message = getJsProp(error, 'message')?.toString();
  final code = getJsProp(error, 'code')?.toString();
  final details = getJsProp(error, 'details')?.toString();
  final parts = <String>[];
  for (final value in [name, message, code, details]) {
    if (value == null) continue;
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    if (skip != null && trimmed == skip) continue;
    parts.add(trimmed);
  }
  if (parts.isEmpty) return null;
  return parts.join(' - ');
}

/// رسالة خطأ ودّية جاهزة للعرض
String prettyError(Object error, [StackTrace? st]) {
  // أخطاءك الودّية
  if (error is Exception && error.runtimeType.toString() == 'UserFriendly') {
    try {
      final msg = (error as dynamic).message?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg;
    } catch (_) {}
  }

  // Firebase
  if (error is FirebaseException) {
    final code = error.code.isNotEmpty ? ' (${error.code})' : '';
    final msg = error.message ?? 'خطأ من Firebase';
    return '$msg$code';
  }

  if (error is FormatException) return error.message;
  if (error is AssertionError) {
    return error.message?.toString() ?? 'Assertion error';
  }

  // على الويب: الأخطاء عادة تكون مغلّفة داخل JS Error
  if (kIsWeb) {
    const convertedMsg =
        "Dart exception thrown from converted Future. Use the properties 'error' to fetch the boxed error and 'stack' to recover the stack trace.";
    final directMsg = _bestJsMessage(error, skip: convertedMsg);
    if (directMsg != null && directMsg.isNotEmpty) {
      return directMsg;
    }
    // 1) جرّب تفك التغليف: error.error هو الـ Dart error الحقيقي
    for (final key in const ['error', 'cause', 'originalError', 'dartError']) {
      final inner = getJsProp(error, key);
      if (inner != null && !identical(inner, error)) {
        final innerMsg = prettyError(inner, st);
        if (innerMsg.isNotEmpty) return innerMsg;
      }
    }

    // 2) جرّب خصائص message / code من الـ JS Error
    final m = getJsProp(error, 'message')?.toString();
    final c = getJsProp(error, 'code')?.toString();
    final stack = getJsProp(error, 'stack')?.toString();

    // لو الرسالة هي بالضبط نص converted Future ولسّا ما عرفنا شي مفيد
    if (m == convertedMsg && (c == null || c.isEmpty)) {
      for (final key in const ['error', 'cause', 'originalError', 'dartError']) {
        final inner = getJsProp(error, key);
        final innerMsg = _bestJsMessage(inner, skip: convertedMsg);
        if (innerMsg != null && innerMsg.isNotEmpty) return innerMsg;
        final innerStack = _firstStackLine(
          getJsProp(inner ?? error, 'stack')?.toString(),
        );
        if (innerStack != null) return innerStack;
      }
      final topStack = _firstStackLine(stack);
      if (topStack != null) return topStack;
      final dartStack = _firstStackLine(st?.toString());
      if (dartStack != null) return dartStack;
      return 'Unexpected error.';
    }

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
      title: const Text(AppStrings.dialogUnableToCompleteOperation),
      content: SingleChildScrollView(child: Text(msg)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.dialogOk),
        ),
      ],
    ),
  );
}

/// لوج خفيف وقت التطوير
void logError(Object e, [StackTrace? st]) {
  // ????? ?? ??????? ??????? ?? ????
  debugPrint('? ERROR: $e');
  if (kIsWeb) {
    final keys = getJsKeys(e);
    if (keys.isNotEmpty) {
      debugPrint('JS keys: ${keys.join(', ')}');
    }
    final json = jsStringify(e);
    if (json != null && json.isNotEmpty && json != 'null') {
      debugPrint('JS json: $json');
    }
    for (final key in const ['error', 'cause', 'originalError', 'dartError']) {
      final inner = getJsProp(e, key);
      if (inner != null && !identical(inner, e)) {
        debugPrint('JS $key: $inner');
        final innerKeys = getJsKeys(inner);
        if (innerKeys.isNotEmpty) {
          debugPrint('JS $key keys: ${innerKeys.join(', ')}');
        }
        final innerJson = jsStringify(inner);
        if (innerJson != null && innerJson.isNotEmpty && innerJson != 'null') {
          debugPrint('JS $key json: $innerJson');
        }
        final innerMsg = getJsProp(inner, 'message')?.toString();
        final innerCode = getJsProp(inner, 'code')?.toString();
        final innerStack = getJsProp(inner, 'stack')?.toString();
        if (innerMsg != null && innerMsg.isNotEmpty) {
          debugPrint('JS $key message: $innerMsg');
        }
        if (innerCode != null && innerCode.isNotEmpty) {
          debugPrint('JS $key code: $innerCode');
        }
        if (innerStack != null && innerStack.isNotEmpty) {
          debugPrint('JS $key stack:\n$innerStack');
        }
      }
    }
    final m = getJsProp(e, 'message')?.toString();
    final c = getJsProp(e, 'code')?.toString();
    final stack = getJsProp(e, 'stack')?.toString();
    if (m != null && m.isNotEmpty) debugPrint('JS message: $m');
    if (c != null && c.isNotEmpty) debugPrint('JS code: $c');
    if (stack != null && stack.isNotEmpty) {
      debugPrint('JS stack:\n$stack');
    }
  }
  if (st != null) debugPrint('STACK:\n$st');
}
