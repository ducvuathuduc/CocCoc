// Test-only: take the committed vi_en content and re-sign selected bundles after adding the
// server-owned authored mode configuration (`modeConfig`). The dev content key is well known; see
// src/testing/dev-content-key.ts. Returns a file store and publication for createTestApp().
export async function authoredContent(kit, patches) {
  const local = kit.loadLocalContent();
  const publication = local.publications.find((p) => p.courseId === 'vi_en');
  if (!publication) throw new Error('vi_en content is not committed');
  const texts = new Map();
  const manifest = JSON.parse(await local.files.read(publication.manifestFileId));
  const privateKey = kit.devContentPrivateKey();
  for (const [lessonId, modeConfig] of Object.entries(patches)) {
    const index = manifest.bundles.find((b) => b.lessonId === lessonId);
    if (!index) throw new Error(`no authored bundle for ${lessonId}`);
    const bundle = JSON.parse(texts.get(index.fileId) ?? (await local.files.read(index.fileId)));
    bundle.modeConfig = modeConfig;
    bundle.signatureKeyId = kit.DEV_CONTENT_KEY_ID;
    bundle.signature = kit.signText(privateKey, kit.bundleSigningInput(bundle));
    const text = kit.canonicalJson(bundle);
    texts.set(index.fileId, text);
    index.sha256 = kit.sha256(text);
  }
  manifest.signatureKeyId = kit.DEV_CONTENT_KEY_ID;
  manifest.signature = kit.signText(privateKey, kit.manifestSigningInput(manifest));
  const manifestText = kit.canonicalJson(manifest);
  texts.set(publication.manifestFileId, manifestText);
  return {
    files: {
      read: async (fileId) => texts.get(fileId) ?? (await local.files.read(fileId)),
    },
    publication: { ...publication, manifestSha256: kit.sha256(manifestText) },
  };
}
