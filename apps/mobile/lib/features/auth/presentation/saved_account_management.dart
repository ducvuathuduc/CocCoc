import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../application/auth_controller.dart';
import '../domain/auth_state.dart';

class SavedAccountManagementScreen extends ConsumerStatefulWidget {
  const SavedAccountManagementScreen({required this.account, super.key});

  final AuthUser account;

  @override
  ConsumerState<SavedAccountManagementScreen> createState() =>
      _SavedAccountManagementScreenState();
}

class _SavedAccountManagementScreenState
    extends ConsumerState<SavedAccountManagementScreen> {
  final _removeKey = GlobalKey();

  Future<void> _showRemoveMenu() async {
    final buttonContext = _removeKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final button = buttonContext?.findRenderObject() as RenderBox?;
    if (overlay == null || button == null) return;
    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    const sourceWidth = 236.0;
    const sourceHeight = 78.0;
    final popupWidth = sourceWidth.clamp(0, overlay.size.width - 20).toDouble();
    final left = (topLeft.dx - 22).clamp(
      10.0,
      overlay.size.width - popupWidth - 10,
    );
    final top = (topLeft.dy - sourceHeight - 14).clamp(
      8.0,
      overlay.size.height - sourceHeight - 18,
    );
    final pointerX = (topLeft.dx + button.size.width / 2 - left)
        .clamp(22.0, popupWidth - 22)
        .toDouble();
    final selected = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss remove account menu',
      barrierColor: Colors.transparent,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, primary, secondary) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            height: sourceHeight + 10,
            child: _RemoveAccountPopover(
              pointerX: pointerX,
              onRemove: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
        ],
      ),
    );
    if (selected != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).forgetRemembered();
    if (!mounted) return;
    if (ref.read(authControllerProvider).remembered == null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = widget.account.name.isEmpty
        ? widget.account.email
        : widget.account.name;
    return PopScope(
      canPop: !auth.busy,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Manage Accounts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ReferenceColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(minHeight: 96),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: ReferenceColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ReferenceColors.border, width: 2),
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'Remove saved account',
                        button: true,
                        enabled: !auth.busy,
                        child: ExcludeSemantics(
                          child: InkResponse(
                            key: _removeKey,
                            onTap: auth.busy ? null : _showRemoveMenu,
                            radius: 26,
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(child: _RemoveAccountIcon()),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF58A700),
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: ReferenceColors.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.account.email,
                              style: const TextStyle(
                                color: ReferenceColors.disabled,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextButton(
                  onPressed: auth.busy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'DONE EDITING',
                    style: TextStyle(
                      color: ReferenceColors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                if (auth.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                if (auth.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        auth.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFA41414),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _RemoveAccountPopover extends StatelessWidget {
  const _RemoveAccountPopover({required this.pointerX, required this.onRemove});

  final double pointerX;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: pointerX - 9,
        top: 68,
        child: Transform.rotate(
          angle: .785398,
          child: Container(
            width: 18,
            height: 18,
            color: ReferenceColors.surface,
          ),
        ),
      ),
      Positioned.fill(
        bottom: 10,
        child: Material(
          color: ReferenceColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRemove,
            child: const Center(
              child: Text(
                'Remove',
                style: TextStyle(
                  color: Color(0xFFFF4B4B),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _RemoveAccountIcon extends StatelessWidget {
  const _RemoveAccountIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: const BoxDecoration(
      color: Color(0xFFFF4B4B),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 12,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}
