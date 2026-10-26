import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { prepareLocalConfig } from '../scripts/local-config.mjs';

test('local configuration is isolated, restart-safe and never admits an unprobed database', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-local-'));
  try {
    prepareLocalConfig(dir);
    const first = fs.readFileSync(path.join(dir, 'appwrite.env'), 'utf8');
    const compose = fs.readFileSync(path.join(dir, 'compose.env'), 'utf8');
    assert.match(first, /_APP_VERSION=2\.3\.0/);
    assert.match(first, /_APP_SMTP_HOST=mailpit/);
    assert.match(first, /_APP_DB_HOST=postgresql/);
    assert.match(first, /_APP_STORAGE_LIMIT=30000000/);
    assert.doesNotMatch(first, /cloud\.appwrite|your-secret|password=password/);
    assert.match(compose, /^COMPOSE_PROJECT_NAME=cocenglish-dev/m);
    const learning = fs.readFileSync(path.join(dir, 'learning.env'), 'utf8');
    assert.match(learning, /APPWRITE_ENDPOINT=https:\/\/local-tls:8443\/v1/);
    assert.match(learning, /COC_LEARNING_PERSISTENCE=disabled/);
    assert.doesNotMatch(learning, /reviewed-cloud-gate|APPWRITE_API_KEY/);
    prepareLocalConfig(dir);
    assert.equal(fs.readFileSync(path.join(dir, 'appwrite.env'), 'utf8'), first);
    assert.equal(fs.readFileSync(path.join(dir, 'compose.env'), 'utf8'), compose);
    const credentials = JSON.parse(fs.readFileSync(path.join(dir, 'console.json')));
    assert.equal(credentials.email, 'admin@cocenglish.local');
    assert.ok(credentials.password.length >= 32);
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});

test('partial existing configuration fails safely instead of rotating database credentials', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-local-'));
  try {
    fs.writeFileSync(path.join(dir, 'appwrite.env'), 'existing-private-config');
    assert.throws(() => prepareLocalConfig(dir), /PARTIAL_LOCAL_CONFIGURATION/);
    assert.equal(
      fs.readFileSync(path.join(dir, 'appwrite.env'), 'utf8'),
      'existing-private-config',
    );
  } finally {
    fs.rmSync(dir, { recursive: true });
  }
});
