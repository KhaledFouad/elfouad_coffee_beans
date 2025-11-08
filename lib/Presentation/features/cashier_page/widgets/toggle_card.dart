import 'package:flutter/material.dart';

/// ToggleCard
/// كارت اختيار صغير بنفس ستايل البني المستخدم في المشروع.
/// يعمل كـ Checkbox مخصّص: ضيافة / محوّج / أجِّل ... إلخ.
///
/// الاستخدام:
/// ToggleCard(
///   title: 'أجِّل (الزبون لسه مادفعش)',
///   value: isDeferred,
///   onChanged: (v) => setState(() => isDeferred = v),
/// )
class ToggleCard extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// يعطّل التفاعل (مثلاً أثناء الـ saving)
  final bool busy;

  /// نص صغير اختياري تحت العنوان
  final String? subtitle;

  /// أيقونة اختيارية تظهر قبل العنوان (شكل جمالي)
  final IconData? leadingIcon;

  /// تخصيص ألوان عند الحاجة (القيم الافتراضية مطابقة لـ _toggleCard القديم)
  final Color? selectedBg;
  final Color? unselectedBg;
  final Color? selectedBorder;
  final Color? unselectedBorder;
  final Color? selectedText;
  final Color? unselectedText;

  const ToggleCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.busy = false,
    this.subtitle,
    this.leadingIcon,

    // ألوان افتراضية مطابقة للكود اللي اديتهولي
    this.selectedBg = const Color(0xFF543824),
    this.unselectedBg,
    this.selectedBorder,
    this.unselectedBorder,
    this.selectedText = Colors.white,
    this.unselectedText = const Color(0xFF543824),
  });

  @override
  Widget build(BuildContext context) {
    // لو المستخدم ما بعثش ألوان غير المختارة، نولّد الافتراضيات من Theme
    final Color resolvedUnselectedBg =
        unselectedBg ?? Colors.brown.shade50;
    final Color resolvedSelectedBorder =
        selectedBorder ?? Colors.brown.shade700;
    final Color resolvedUnselectedBorder =
        unselectedBorder ?? Colors.brown.shade100;

    return Semantics(
      container: true,
      label: title,
      child: Container(
        decoration: BoxDecoration(
          color: value ? (selectedBg!) : resolvedUnselectedBg,
          border: Border.all(
            color: value ? resolvedSelectedBorder : resolvedUnselectedBorder,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CheckboxListTile(
          value: value,
          onChanged: busy ? null : (v) => onChanged(v ?? false),
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,

          // العنوان + أيقونة اختيارية
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 16,
                  color: value ? (selectedText!) : (unselectedText!),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value ? (selectedText!) : (unselectedText!),
                    fontWeight: FontWeight.w900,
                    fontSize: 12, // صغير وموحّد
                  ),
                ),
              ),
            ],
          ),

          // وصف اختياري صغير
          subtitle: (subtitle == null)
              ? null
              : Text(
                  subtitle!,
                  style: TextStyle(
                    color: value
                        ? (selectedText!).withValues(alpha: 0.9)
                        : (unselectedText!).withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),

          // ألوان مربع الـ checkbox
          activeColor: Colors.white, // لون تعبئة المربع لما يكون مُفعّل
          checkColor: selectedBg, // لون علامة الصح
        ),
      ),
    );
  }
}
