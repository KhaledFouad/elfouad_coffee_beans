// lib/utils_error.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:js_util' as js_util; // لقراءة خصائص JS بأمان

// قراءة خاصية من كائن JS بأمان (ترجع '' لو مش موجود/مش متاح)
String _readJsProp(Object? o, String prop) {
  if (o == null) return '';
  try {
    if (js_util.hasProperty(o, prop)) {
      final v = js_util.getProperty(o, prop);
      return (v == null) ? '' : v.toString();
    }
  } catch (_) {}
  return '';
}

String unwrapWeb(Object e, [StackTrace? st]) {
  final sb = StringBuffer();

  // الأساس
  sb.writeln(e.toString());

  // حاول تقرأ message/code/name/stack من كائنات JS (ويب فقط)
  try {
    final name = _readJsProp(e, 'name');
    final code = _readJsProp(e, 'code');
    final message = _readJsProp(e, 'message');
    final jsStack = _readJsProp(e, 'stack');

    if (name.isNotEmpty || code.isNotEmpty || message.isNotEmpty) {
      sb.writeln('\n[JS fields]');
      if (name.isNotEmpty) sb.writeln('name: $name');
      if (code.isNotEmpty) sb.writeln('code: $code');
      if (message.isNotEmpty) sb.writeln('message: $message');
    }
    if (jsStack.isNotEmpty) {
      sb.writeln('\n[JS stack]');
      sb.writeln(jsStack);
    }
  } catch (_) {
    // تجاهل أي أخطاء interop
  }

  if (st != null) {
    sb.writeln('\n[Dart stack]');
    sb.writeln(st);
  }
  return sb.toString();
}

void logError(Object e, [StackTrace? st]) {
  // اطبع نص فقط، بدون تمرير كائنات “بوكسد” للـ VM service
  final msg = unwrapWeb(e, st);
  // debugPrint بيقسّم النص تلقائيًا (سلامة)
  debugPrint('❌ $msg');
}

Future<void> showErrorDialog(
  BuildContext context,
  Object e, [
  StackTrace? st,
]) async {
  final msg = unwrapWeb(e, st);

  if (!context.mounted) return;
  // افتح الديالوج في microtask لتجنب أي "setState during build"
  await Future.microtask(() {});

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تفاصيل الخطأ'),
      content: SizedBox(
        width: 720,
        child: SelectableText(msg, style: const TextStyle(fontSize: 13)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: msg));
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ تفاصيل الخطأ')),
              );
            }
          },
          child: const Text('نسخ'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}
