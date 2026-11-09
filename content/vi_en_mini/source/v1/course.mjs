// vi_en_mini v1 — the second course, used to prove the generator, the gates and the publish path are
// genuinely multi-course. One section and one unit: small enough to build inside a test, complete
// enough to pass tools/content/lint-course.mjs.
//
//   node tools/content/build-course.mjs --course vi_en_mini --version v1
//   node tools/content/lint-course.mjs   --course vi_en_mini --version v1
//
// Only the source tables and the build report are committed; dist/ is generated on demand.
import * as u01 from './units/u01-animals.mjs';

export const course = {
  courseId: 'vi_en_mini',
  title: 'Khóa mẫu: Động vật',
  sourceLocale: 'vi-VN',
  targetLocale: 'en-US',
};

export const sections = [
  { sectionId: 'sec1', title: 'Phần 1: Động vật quanh em', units: ['animals'] },
];

export const unitModules = [u01];
