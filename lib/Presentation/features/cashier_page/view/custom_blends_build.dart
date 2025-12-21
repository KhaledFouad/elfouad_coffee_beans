part of 'custom_blends_page.dart';

mixin _CustomBlendsBuild on _CustomBlendsStateBase {
  Widget _buildPage(BuildContext context) {
    final titleSize = ResponsiveValue<double>(
      context,
      defaultValue: 28,
      conditionalValues: const [
        Condition.smallerThan(name: TABLET, value: 22),
        Condition.between(
          start: AppBreakpoints.tabletStart,
          end: AppBreakpoints.tabletEnd,
          value: 26,
        ),
        Condition.largerThan(name: DESKTOP, value: 32),
      ],
    ).value;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.only(bottom: 12),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.maybePop(context),
                tooltip: AppStrings.tooltipBack,
              ),
              title: Text(
                AppStrings.titleCustomBlends,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: titleSize,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _allItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, c) {
                  final maxWidth = c.maxWidth;
                  final isWide = AppBreakpoints.isDesktop(maxWidth);
                  final horizontalPadding = maxWidth < 600 ? 12.0 : 16.0;
                  final composer = SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      90,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              AppStrings.labelBlendComponents,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  const Color(0xFF543824),
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _lines.add(_BlendLine()),
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text(AppStrings.labelAddComponent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._lines.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final line = entry.value;
                          return Padding(
                            key: ValueKey('line_$idx'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LineCard(
                              items: _allItems,
                              line: line,
                              onChanged: () => setState(() {}),
                              onRemove: _lines.length == 1 || _busy
                                  ? null
                                  : () => setState(() {
                                      if (_showPad && _padLineIndex == idx) {
                                        _closePad();
                                      }
                                      _lines.removeAt(idx);
                                    }),
                              onTapGrams: () => _openPadForLine(
                                idx,
                                _PadTargetType.lineGrams,
                              ),
                              onTapPrice: () => _openPadForLine(
                                idx,
                                _PadTargetType.linePrice,
                              ),
                            ),
                          );
                        }),
                        if (_fatal != null) ...[
                          const SizedBox(height: 8),
                          _WarningBox(text: _fatal!),
                        ],
                        // نومباد داخلي أسفل القائمة
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: _showPad
                              ? _numPad(
                                  allowDot:
                                      _padType == _PadTargetType.linePrice,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );

                  final totals = Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      80,
                    ),
                    child: _TotalsCard(
                      isComplimentary: _isComplimentary,
                      onComplimentaryChanged: _busy
                          ? null
                          : (v) => _setComplimentary(v ?? false),
                      isDeferred: _isDeferred,
                      onDeferredChanged: _busy
                          ? null
                          : (v) => _setDeferred(v ?? false),
                      isSpiced: _isSpiced && _canSpiceAny,
                      onSpicedChanged: _busy || !_canSpiceAny
                          ? null
                          : (v) => setState(() => _isSpiced = v ?? false),
                      titleController: _titleCtrl,
                      titleEnabled: !_busy,
                      ginsengGrams: _ginsengGrams,
                      onGinsengMinus: _busy
                          ? null
                          : () => setState(() {
                              _ginsengGrams = (_ginsengGrams > 0)
                                  ? _ginsengGrams - 1
                                  : 0;
                            }),
                      onGinsengPlus: _busy
                          ? null
                          : () => setState(() => _ginsengGrams += 1),
                      totalGrams: _sumGrams,
                      beansAmount: _sumPriceLines,
                      spiceAmount: _isComplimentary ? 0.0 : _spiceAmount,
                      ginsengAmount: _isComplimentary
                          ? 0.0
                          : _ginsengPriceAmount,
                      totalPrice: _uiTotal,
                      noteController: _noteCtrl,
                      noteVisible: _isDeferred,
                      noteEnabled: !_busy,
                    ),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: composer),
                        SizedBox(
                          width: 360,
                          height: c.maxHeight,
                          child: SingleChildScrollView(child: totals),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                      child: Column(
                        children: [
                          composer,
                          const SizedBox(height: 12),
                          totals,
                        ],
                      ),
                    );
                  }
                },
              ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(blurRadius: 8, color: Colors.black12),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    child: const Text(
                      AppStrings.dialogCancel,
                      style: TextStyle(color: Color(0xFF543824)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(0xFF543824),
                      ),
                    ),
                    onPressed: _busy ? null : _commitSale,
                    onLongPress:
                        _busy || !_canQuickConfirm ? null : _commitInstantInvoice,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text(AppStrings.dialogConfirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
