part of 'single_dialog.dart';

mixin _SingleDialogPad on _SingleDialogStateBase {
  @override
  void _openPad(_PadTarget target) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _padTarget = target;
      _showPad = true;
    });
  }

  @override
  void _closePad() {
    setState(() {
      _showPad = false;
      _padTarget = _PadTarget.none;
    });
  }

  void _applyPadKey(String k) {
    final ctrl = (_padTarget == _PadTarget.grams) ? _gramsCtrl : _moneyCtrl;
    if (k == 'back') {
      if (ctrl.text.isNotEmpty) {
        ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
      }
    } else if (k == 'clear') {
      ctrl.clear();
    } else if (k == 'dot') {
      if (_padTarget == _PadTarget.money && !ctrl.text.contains('.')) {
        ctrl.text = ctrl.text.isEmpty ? '0.' : '${ctrl.text}.';
      }
    } else if (k == 'done') {
      _closePad();
      return;
    } else {
      ctrl.text += k;
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
          margin: const EdgeInsets.only(top: 12),
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
