import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/app_theme.dart';
import 'bar_button.dart';
import 'search_field.dart';

class SourceBar extends StatelessWidget {
  const SourceBar({
    super.key,
    required this.source,
    required this.onSwitchSource,
    required this.onOpenSearch,
    required this.onSearchSubmitted,
    this.searchController,
    this.recentSearches = const [],
    this.onForgetSearch,
    this.televisionLeading,
    this.leading = const [],
    this.actions = const [],
  });
  final List<Widget> leading;
  final String source;
  final void Function(BuildContext anchor) onSwitchSource;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onSearchSubmitted;
  final TextEditingController? searchController;
  final List<String> recentSearches;
  final ValueChanged<String>? onForgetSearch;
  final Widget? televisionLeading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final form = AppScope.formFactorOf(context);
    final hint = '在 $source 中搜索';
    final search = BarButton(
      icon: Icons.search_rounded,
      tooltip: hint,
      onPressed: onOpenSearch,
    );
    final pill = Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Builder(
          builder: (anchor) => _SourceSwitcherPill(
            label: source,
            onTap: () => onSwitchSource(anchor),
          ),
        ),
      ),
    );
    return switch (form) {
      FormFactor.phone => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              ...leading,
              if (leading.isNotEmpty) const SizedBox(width: 4),
              Builder(
                builder: (anchor) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: _SourceSwitcherPill(
                    label: source,
                    onTap: () => onSwitchSource(anchor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhoneSearchPill(hint: hint, onTap: onOpenSearch),
              ),
              ...actions,
            ],
          ),
        ),
      ),
      FormFactor.pad || FormFactor.window => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              ...leading,
              if (leading.isNotEmpty) const SizedBox(width: 6),
              pill,
              const SizedBox(width: 8),
              _RecentSearchField(
                width: MediaQuery.sizeOf(context).width >= 900 ? 320 : 240,
                hint: hint,
                controller: searchController,
                recent: recentSearches,
                onSubmitted: onSearchSubmitted,
                onForget: onForgetSearch,
              ),
              const SizedBox(width: 4),
              ...actions,
            ],
          ),
        ),
      ),
      FormFactor.television => SizedBox(
        height: 48,
        child: Row(
          spacing: 10,
          children: [
            ?televisionLeading,
            const Spacer(),
            Text(
              source,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Builder(
              builder: (anchor) => BarButton(
                icon: Icons.public_rounded,
                tooltip: '切换站源',
                onPressed: () => onSwitchSource(anchor),
              ),
            ),
            search,
            ...actions,
          ],
        ),
      ),
    };
  }
}

class _SourceSwitcherPill extends StatelessWidget {
  const _SourceSwitcherPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: '切换站源 $label',
      child: Tooltip(
        message: '切换站源',
        child: Material(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
          shape: StadiumBorder(
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSearchField extends StatefulWidget {
  const _RecentSearchField({
    required this.width,
    required this.hint,
    required this.controller,
    required this.recent,
    required this.onSubmitted,
    required this.onForget,
  });
  final double width;
  final String hint;
  final TextEditingController? controller;
  final List<String> recent;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onForget;

  @override
  State<_RecentSearchField> createState() => _RecentSearchFieldState();
}

class _RecentSearchFieldState extends State<_RecentSearchField> {
  final _ownController = TextEditingController();
  final _focus = FocusNode();
  final _overlay = OverlayPortalController()..show();
  final _link = LayerLink();
  var _active = false;

  TextEditingController get _controller => widget.controller ?? _ownController;

  @override
  void dispose() {
    _ownController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String query) {
    _focus.unfocus();
    widget.onSubmitted(query);
  }

  Widget _options(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!_active || _controller.text.isNotEmpty || widget.recent.isEmpty) {
        return const SizedBox.shrink();
      }
      return CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: TextFieldTapRegion(
            child: SizedBox(
              width: widget.width,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      for (final query in widget.recent)
                        GestureDetector(
                          onSecondaryTap: () => widget.onForget?.call(query),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.history_rounded,
                              size: 18,
                            ),
                            title: Text(
                              query,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pick(query),
                            onLongPress: () => widget.onForget?.call(query),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) => setState(() => _active = value),
    child: CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: _options,
        child: SizedBox(
          width: widget.width,
          child: SearchField(
            hint: widget.hint,
            controller: _controller,
            focusNode: _focus,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
    ),
  );
}

class _PhoneSearchPill extends StatelessWidget {
  const _PhoneSearchPill({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
      shape: StadiumBorder(
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
