import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');
const sha256 = (relativePath) =>
  crypto
    .createHash('sha256')
    .update(fs.readFileSync(path.join(root, relativePath)))
    .digest('hex');

const project = read('apps/mobile/ios/Runner.xcodeproj/project.pbxproj');
const runnerInfo = read('apps/mobile/ios/Runner/Info.plist');

test('Runner registers the ordered lesson ActivityKit channel', () => {
  const appDelegate = read('apps/mobile/ios/Runner/AppDelegate.swift');
  const bridge = read('apps/mobile/ios/Runner/LessonActivityBridge.swift');

  assert.match(appDelegate, /LessonActivityBridge\(messenger:/);
  assert.match(appDelegate, /pluginRegistry\.registrar\(/);
  assert.match(appDelegate, /registrar\.messenger\(\)/);
  assert.match(bridge, /@MainActor\s+final class LessonActivityBridge/);
  assert.match(bridge, /private var pendingTask: Task<Void, Never>\?/);
  assert.match(bridge, /await previous\?\.value/);
  assert.match(bridge, /cocenglish\/lesson_activity/);
  assert.match(bridge, /case "sync"/);
  assert.match(bridge, /case "end"/);
  for (const field of [
    'lessonId',
    'completed',
    'total',
    'hearts',
    'unlimited',
    'elapsedSeconds',
    'streak',
    'paused',
  ]) {
    assert.match(bridge, new RegExp(`"${field}"`), field);
  }
  assert.match(bridge, /areActivitiesEnabled/);
  assert.match(bridge, /applicationState == \.active/);
  assert.match(bridge, /ActivityContent/);
  assert.match(bridge, /pushType: nil/);
  assert.match(bridge, /Activity<LessonActivityAttributes>\.activities/);
  assert.match(runnerInfo, /<key>NSSupportsLiveActivities<\/key>\s*<true\/>/);
});

test('shared ActivityAttributes compile in Runner and StreakWidget source phases', () => {
  const attributes = read('apps/mobile/ios/Shared/LessonActivityAttributes.swift');
  assert.match(attributes, /struct LessonActivityAttributes: ActivityAttributes/);
  assert.match(attributes, /struct ContentState: Codable, Hashable/);
  assert.equal((project.match(/LessonActivityAttributes\.swift in Sources/g) ?? []).length, 4);
  assert.match(project, /LessonActivityBridge\.swift in Sources/);
  assert.match(project, /LessonLiveActivity\.swift in Sources/);
  assert.match(project, /StreakWidgetBundle\.swift in Sources/);
  assert.match(project, /Assets\.xcassets in Resources/);
});

test('widget bundle exposes home widget and every Live Activity presentation', () => {
  const bundle = read('apps/mobile/ios/StreakWidget/StreakWidgetBundle.swift');
  const liveActivity = read('apps/mobile/ios/StreakWidget/LessonLiveActivity.swift');

  assert.match(bundle, /@main\s+struct StreakWidgetBundle: WidgetBundle/);
  assert.match(bundle, /StreakWidget\(\)/);
  assert.match(bundle, /LessonLiveActivity\(\)/);
  assert.match(liveActivity, /ActivityConfiguration\(for: LessonActivityAttributes\.self\)/);
  assert.match(liveActivity, /DynamicIslandExpandedRegion\(\.leading\)/);
  assert.match(liveActivity, /DynamicIslandExpandedRegion\(\.trailing\)/);
  assert.match(liveActivity, /DynamicIslandExpandedRegion\(\.bottom\)/);
  assert.match(liveActivity, /compactLeading:/);
  assert.match(liveActivity, /compactTrailing:/);
  assert.match(liveActivity, /minimal:/);
  assert.match(liveActivity, /cocenglish:\/\/\/activity\/resume/);
});

test('all seven source-backed home widget moods have verified image crops', () => {
  const referencePath = 'apps/mobile/ios/StreakWidget/ReferenceAssets.json';
  const references = JSON.parse(read(referencePath));
  const expectedMoods = ['ready', 'early', 'practice', 'lastChance', 'save', 'protected', 'away'];

  assert.deepEqual(Object.keys(references.streakWidget).sort(), expectedMoods.sort());
  for (const mood of expectedMoods) {
    const entry = references.streakWidget[mood];
    assert.match(entry.source.id, /^sc_[0-9a-f]{32}$/);
    assert.match(entry.source.url, /^https:\/\/storage\.gummble\.com\//);
    assert.match(entry.source.sha256, /^[0-9a-f]{64}$/);
    for (const size of ['medium', 'small']) {
      const crop = entry.crops[size];
      assert.ok(crop.width > 0 && crop.height > 0, `${mood}.${size}`);
      assert.equal(sha256(crop.file), crop.sha256, `${mood}.${size}`);
    }
  }

  assert.deepEqual(Object.keys(references.liveActivity).sort(), [
    'compactIslandIcon',
    'expandedAppIcon',
    'expandedProgressReference',
    'lockScreenDuo',
    'streakWarningDuo',
  ]);
  for (const entry of Object.values(references.liveActivity)) {
    assert.match(entry.source.id, /^sc_[0-9a-f]{32}$/);
    assert.match(entry.source.sha256, /^[0-9a-f]{64}$/);
    assert.ok(entry.region.width > 0 && entry.region.height > 0);
    if (entry.file) assert.equal(sha256(entry.file), entry.sha256, entry.assetName);
  }
});
