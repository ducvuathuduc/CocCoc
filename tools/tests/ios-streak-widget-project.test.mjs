import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const project = read('apps/mobile/ios/Runner.xcodeproj/project.pbxproj');
const widgetInfo = read('apps/mobile/ios/StreakWidget/Info.plist');
const runnerEntitlements = read('apps/mobile/ios/Runner/Runner.entitlements');
const widgetEntitlements = read('apps/mobile/ios/StreakWidget/StreakWidget.entitlements');

test('Runner embeds a configured StreakWidget extension target', () => {
  assert.match(
    project,
    /[A-F0-9]+ \/\* StreakWidget \*\/ = \{[\s\S]*?productType = "com\.apple\.product-type\.app-extension";/,
  );
  assert.match(project, /StreakWidget\.swift in Sources/);
  assert.match(project, /StreakWidget\.appex in Embed App Extensions/);
  assert.match(
    project,
    /Embed App Extensions[\s\S]*?dstSubfolderSpec = 13;[\s\S]*?StreakWidget\.appex in Embed App Extensions/,
  );
  assert.match(
    project,
    /97C146ED1CF9000F007C117D \/\* Runner \*\/ = \{[\s\S]*?dependencies = \([\s\S]*?StreakWidget[\s\S]*?\);/,
  );
});

test('StreakWidget has complete extension-safe build settings in every configuration', () => {
  assert.equal(
    (project.match(/PRODUCT_BUNDLE_IDENTIFIER = com\.cocenglish\.cocenglish\.StreakWidget;/g) ?? [])
      .length,
    3,
  );
  assert.equal(
    (project.match(/CODE_SIGN_ENTITLEMENTS = StreakWidget\/StreakWidget\.entitlements;/g) ?? [])
      .length,
    3,
  );
  assert.equal((project.match(/APPLICATION_EXTENSION_API_ONLY = YES;/g) ?? []).length, 3);
  assert.equal((project.match(/IPHONEOS_DEPLOYMENT_TARGET = 17\.0;/g) ?? []).length, 3);
  assert.equal(
    (project.match(/CURRENT_PROJECT_VERSION = "\$\(FLUTTER_BUILD_NUMBER\)";/g) ?? []).length,
    6,
  );
  assert.equal((project.match(/MARKETING_VERSION = "\$\(FLUTTER_BUILD_NAME\)";/g) ?? []).length, 3);
  assert.doesNotMatch(project, /DEVELOPMENT_TEAM =/);
});

test('Runner and StreakWidget share the declared App Group', () => {
  assert.equal(
    (project.match(/CODE_SIGN_ENTITLEMENTS = Runner\/Runner\.entitlements;/g) ?? []).length,
    3,
  );
  for (const entitlements of [runnerEntitlements, widgetEntitlements]) {
    assert.match(
      entitlements,
      /<key>com\.apple\.security\.application-groups<\/key>[\s\S]*?<string>group\.com\.cocenglish\.cocenglish<\/string>/,
    );
  }
});

test('StreakWidget uses a complete WidgetKit extension plist', () => {
  for (const key of [
    'CFBundleExecutable',
    'CFBundleIdentifier',
    'CFBundleInfoDictionaryVersion',
    'CFBundleName',
    'CFBundlePackageType',
    'CFBundleShortVersionString',
    'CFBundleVersion',
  ]) {
    assert.match(widgetInfo, new RegExp(`<key>${key}<\\/key>`), key);
  }
  assert.match(
    widgetInfo,
    /<key>NSExtensionPointIdentifier<\/key>\s*<string>com\.apple\.widgetkit-extension<\/string>/,
  );
});
