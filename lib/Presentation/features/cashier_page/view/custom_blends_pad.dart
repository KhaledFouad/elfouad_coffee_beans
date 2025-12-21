part of 'custom_blends_page.dart';

mixin _CustomBlendsPad on _CustomBlendsStateBase {
  @override
  void _openPadForLine(int lineIndex, _PadTargetType type) {
    if (_busy) return;
    FocusScope.of(context).unfocus(); // اقفل كيبورد النظام
    _padLineIndex = lineIndex;
    _padType = type;

    final line = _lines[_padLineIndex];
    if (_padType == _PadTargetType.lineGrams) {
      _padBuffer = line.grams > 0 ? '${line.grams}' : '';
    } else if (_padType == _PadTargetType.linePrice) {
      _padBuffer = line.price > 0 ? line.price.toStringAsFixed(2) : '';
    } else {
      _padBuffer = '';
    }

    setState(() => _showPad = true);
  }

  @override
  void _closePad() {
    setState(() {
      _showPad = false;
      _padType = _PadTargetType.none;
      _padLineIndex = -1;
      _padBuffer = '';
    });
  }

  void _applyPadKey(String k) {
    if (_padLineIndex < 0 || _padLineIndex >= _lines.length) return;
    final line = _lines[_padLineIndex];

    if (k == 'back') {
      if (_padBuffer.isNotEmpty) {
        _padBuffer = _padBuffer.substring(0, _padBuffer.length - 1);
      }
    } else if (k == 'clear') {
      _padBuffer = '';
    } else if (k == 'dot') {
      // نقطة مسموحة في "السعر" فقط
      if (_padType == _PadTargetType.linePrice && !_padBuffer.contains('.')) {
        _padBuffer = _padBuffer.isEmpty ? '0.' : '$_padBuffer.';
      }
    } else if (k == 'done') {
      _closePad();
      return;
    } else {
      // أرقام
      _padBuffer += k;
    }

    // طبّق القيمة على السطر مباشرة (عرض حيّ)
    if (_padType == _PadTargetType.lineGrams) {
      final v = int.tryParse(_padBuffer.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      line.grams = v.clamp(0, 1000000);
    } else if (_padType == _PadTargetType.linePrice) {
      final cleaned = _padBuffer
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      final v = double.tryParse(cleaned) ?? 0.0;
      line.price = v.clamp(0, 1000000).toDouble();
    }

    setState(() {});
  }

  @override
  Widget _numPad({required bool allowDot}) {
    final keys = <String>[
      '3',
      '2',
      '1',
      '6',
      '5',
      '4',
      '9',
      '8',
      '7',
      allowDot ? 'dot' : 'clear',
      '0',
      'back',
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final btnW = (maxW - (3 * 8) - (2 * 12)) / 3;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.brown.shade100),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keys.map((k) {
                  IconData? icon;
                  String label = k;
                  VoidCallback onTap;

                  switch (k) {
                    case 'back':
                      icon = Icons.backspace_outlined;
                      label = '';
                      onTap = () => _applyPadKey('back');
                      break;
                    case 'clear':
                      icon = Icons.clear;
                      label = '';
                      onTap = () => _applyPadKey('clear');
                      break;
                    case 'dot':
                      label = '.';
                      onTap = () => _applyPadKey('dot');
                      break;
                    default:
                      onTap = () => _applyPadKey(k);
                  }

                  return SizedBox(
                    width: btnW,
                    height: 52,
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : onTap,
                      child: icon != null
                          ? Icon(icon)
                          : Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      const Color(0xFF543824),
                    ),
                  ),
                  onPressed: _busy ? null : () => _applyPadKey('done'),
                  child: const Text(
                    AppStrings.btnDone,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
