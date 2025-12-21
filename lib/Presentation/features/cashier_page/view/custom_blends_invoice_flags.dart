part of 'custom_blends_page.dart';

mixin _CustomBlendsInvoiceFlags on _CustomBlendsStateBase {
  // تنافي ضيافة وأجِّل
  @override
  void _setComplimentary(bool v) {
    setState(() {
      _isComplimentary = v;
      if (v) {
        _isDeferred = false;
        _noteCtrl.clear();
      }
    });
  }

  @override
  void _setDeferred(bool v) {
    setState(() {
      _isDeferred = v;
      if (v) {
        _isComplimentary = false;
      } else {
        _noteCtrl.clear();
      }
    });
  }
}
