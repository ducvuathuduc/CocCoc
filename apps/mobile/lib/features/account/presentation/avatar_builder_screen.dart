import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/reference_theme.dart';
import '../application/avatar_controller.dart';
import '../data/avatar_assets.dart';
import '../domain/avatar_configuration.dart';
import 'avatar_motion.dart';

class AvatarBuilderScreen extends ConsumerStatefulWidget {
  const AvatarBuilderScreen({super.key});

  @override
  ConsumerState<AvatarBuilderScreen> createState() =>
      _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends ConsumerState<AvatarBuilderScreen> {
  bool _began = false;

  @override
  Widget build(BuildContext context) {
    final catalogLoad = ref.watch(avatarCatalogProvider);
    final state = ref.watch(avatarControllerProvider);
    final loadedCatalog = catalogLoad.value;
    if (loadedCatalog != null && !identical(state.catalog, loadedCatalog)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(avatarControllerProvider.notifier)
              .attachCatalog(loadedCatalog);
        }
      });
    }
    if (!_began && state.catalog.tabs.isNotEmpty) {
      _began = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(avatarControllerProvider.notifier).begin();
      });
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(avatarControllerProvider.notifier).cancel();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: catalogLoad.hasError
              ? _CatalogError(
                  onRetry: () => ref.invalidate(avatarCatalogProvider),
                )
              : state.catalog.tabs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _BuilderBody(state: state),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Could not load avatar'),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('RETRY')),
      ],
    ),
  );
}

class _BuilderBody extends ConsumerWidget {
  const _BuilderBody({required this.state});

  final AvatarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final headerHeight = textScale > 1.4 ? 108.0 : 49.0;
    final previewHeight = (viewport.height * .35).clamp(168.0, 296.0);
    final tab = state.catalog.tabs[state.tabIndex];
    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: Row(
            children: [
              Semantics(
                label: 'Close avatar builder',
                button: true,
                child: IconButton(
                  onPressed: () {
                    ref.read(avatarControllerProvider.notifier).cancel();
                    Navigator.of(context).maybePop();
                  },
                  iconSize: 38,
                  color: const Color(0xFFB7B4B8),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close avatar builder',
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Create Avatar',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ReferenceColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Done',
                button: true,
                enabled: state.dirty,
                child: TextButton(
                  onPressed: state.dirty
                      ? () {
                          final saved = ref
                              .read(avatarControllerProvider.notifier)
                              .save();
                          if (saved) Navigator.of(context).pop();
                        }
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1CB0F6),
                    disabledForegroundColor: const Color(0xFFE5E5E5),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          height: previewHeight,
          color: const Color(0xFFE7E5E8),
          child: AvatarMotion(
            values: state.draft,
            width: viewport.width,
            height: previewHeight,
            animate: true,
          ),
        ),
        _CategoryStrip(state: state),
        Expanded(
          child: _Choices(tab: tab, state: state),
        ),
      ],
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip({required this.state});

  final AvatarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 54,
    color: Colors.white,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < state.catalog.tabs.length; index++)
            Builder(
              builder: (context) {
                final tab = state.catalog.tabs[index];
                final selected = index == state.tabIndex;
                return Semantics(
                  label: '${tab.name} category',
                  button: true,
                  selected: selected,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => ref
                        .read(avatarControllerProvider.notifier)
                        .selectTab(index),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: SvgPicture.asset(
                                selected
                                    ? tab.selectedIconAsset
                                    : tab.unselectedIconAsset,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Container(
                            height: 3,
                            color: selected
                                ? const Color(0xFF1CB0F6)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _Choices extends StatelessWidget {
  const _Choices({required this.tab, required this.state});

  final AvatarTab tab;
  final AvatarState state;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: ValueKey(tab.name),
    slivers: [
      for (final section in tab.sections) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              section.title,
              style: const TextStyle(
                color: ReferenceColors.ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (section.layout == AvatarChoiceLayout.linear)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: section.options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) => _OptionTile(
                  section: section,
                  option: section.options[index],
                  state: state,
                  compact: true,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverGrid.builder(
              itemCount: section.options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, index) => _OptionTile(
                section: section,
                option: section.options[index],
                state: state,
                compact: false,
              ),
            ),
          ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ],
  );
}

class _OptionTile extends ConsumerWidget {
  const _OptionTile({
    required this.section,
    required this.option,
    required this.state,
    required this.compact,
  });

  final AvatarSection section;
  final AvatarOption option;
  final AvatarState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.draft[option.stateName] == option.value;
    final label = '${section.title} option ${_numberLabel(option.value)}';
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => ref
            .read(avatarControllerProvider.notifier)
            .select(option.stateName, option.value),
        child: Container(
          width: compact ? 56 : null,
          padding: compact
              ? const EdgeInsets.all(9)
              : const EdgeInsets.fromLTRB(5, 5, 5, 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDF4FF) : Colors.white,
            border: Border.all(
              color: selected
                  ? const Color(0xFF84D8FF)
                  : const Color(0xFFE5E5E5),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0xFFE5E5E5), offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: option.color == null
                ? AvatarMotion(
                    values: option.previewValues(state.draft),
                    tile: true,
                    animate: false,
                  )
                : ColoredBox(color: _hexColor(option.color!)),
          ),
        ),
      ),
    );
  }

  static String _numberLabel(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  static Color _hexColor(String value) =>
      Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}
