import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> loadController() async {
    final container = ProviderContainer();
    final catalog = await container.read(avatarCatalogProvider.future);
    container.read(avatarControllerProvider.notifier).attachCatalog(catalog);
    return container;
  }

  test('loads the current source catalog and source defaults', () async {
    final container = await loadController();
    addTearDown(container.dispose);

    final state = container.read(avatarControllerProvider);
    expect(state.catalog.tabs.map((tab) => tab.name), [
      'Body',
      'Expression',
      'Hairstyle',
      'Accessories',
      'Facial hair',
      'Headwear',
      'Clothing',
      'Background',
    ]);
    expect(state.catalog.tabs.map((tab) => tab.name), isNot(contains('Mask')));
    expect(state.draft['Body'], 1);
    expect(state.draft['MainHair'], 58);
    expect(state.draft['EyeColor'], 1);
    expect(state.hasAvatar, isFalse);
    expect(state.dirty, isFalse);
  });

  test('validates choices and keeps draft separate until save', () async {
    final container = await loadController();
    addTearDown(container.dispose);
    final controller = container.read(avatarControllerProvider.notifier);

    expect(controller.select('Body', 3), isTrue);
    expect(container.read(avatarControllerProvider).draft['Body'], 3);
    expect(container.read(avatarControllerProvider).saved['Body'], 1);
    expect(container.read(avatarControllerProvider).dirty, isTrue);
    expect(controller.select('Body', 999), isFalse);
    expect(controller.select('UnknownState', 1), isFalse);

    controller.cancel();
    expect(container.read(avatarControllerProvider).draft['Body'], 1);
    expect(container.read(avatarControllerProvider).dirty, isFalse);
    expect(controller.save(), isFalse);

    expect(controller.select('Body', 4), isTrue);
    expect(controller.save(), isTrue);
    expect(container.read(avatarControllerProvider).saved['Body'], 4);
    expect(container.read(avatarControllerProvider).hasAvatar, isTrue);
    expect(container.read(avatarControllerProvider).dirty, isFalse);

    controller.begin();
    expect(container.read(avatarControllerProvider).draft['Body'], 4);
  });

  test('tab selection is range checked', () async {
    final container = await loadController();
    addTearDown(container.dispose);
    final controller = container.read(avatarControllerProvider.notifier);

    controller.selectTab(7);
    expect(container.read(avatarControllerProvider).tabIndex, 7);
    controller.selectTab(8);
    expect(container.read(avatarControllerProvider).tabIndex, 7);
    controller.selectTab(-1);
    expect(container.read(avatarControllerProvider).tabIndex, 7);
  });
}
