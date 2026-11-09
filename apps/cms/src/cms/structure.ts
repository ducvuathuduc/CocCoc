import type { SectionDraft } from './types';

/**
 * `tools/content/build-course.mjs` maps every unit with
 * `sections.find((s) => s.units.includes(unit.theme)).sectionId`, so a theme that is in no section
 * makes the repo builder throw before it reads a single exercise. Membership is keyed by theme
 * (`greetings`), not by the unit id (`01-greetings`).
 */

export const sectionOf = (sections: SectionDraft[], theme: string): string =>
  sections.find((s) => s.units.includes(theme))?.sectionId ?? '';

/** New units land in the last section, the same place a hand-authored course grows. */
export function assignTheme(sections: SectionDraft[], theme: string): SectionDraft[] {
  if (sections.some((s) => s.units.includes(theme))) return sections;
  if (sections.length === 0) return [{ sectionId: 'sec1', title: 'Phần 1', units: [theme] }];
  const last = sections.length - 1;
  return sections.map((s, i) => (i === last ? { ...s, units: [...s.units, theme] } : s));
}

export function unassignTheme(sections: SectionDraft[], theme: string): SectionDraft[] {
  if (!sections.some((s) => s.units.includes(theme))) return sections;
  return sections.map((s) => ({ ...s, units: s.units.filter((t) => t !== theme) }));
}

export function moveTheme(
  sections: SectionDraft[],
  theme: string,
  sectionId: string,
): SectionDraft[] {
  return sections.map((s) => {
    const units = s.units.filter((t) => t !== theme);
    return { ...s, units: s.sectionId === sectionId ? [...units, theme] : units };
  });
}

export function newSection(sections: SectionDraft[]): SectionDraft {
  const taken = new Set(sections.map((s) => s.sectionId));
  let n = sections.length + 1;
  while (taken.has(`sec${n}`)) n += 1;
  return { sectionId: `sec${n}`, title: `Phần ${n}`, units: [] };
}

export function dropSection(sections: SectionDraft[], sectionId: string): SectionDraft[] {
  const target = sections.find((s) => s.sectionId === sectionId);
  if (!target || target.units.length > 0) return sections;
  return sections.filter((s) => s.sectionId !== sectionId);
}

/** Vietnamese problems an admin must fix before the course is safe to export. */
export function structureIssues(sections: SectionDraft[], themes: string[]): string[] {
  const problems: string[] = [];
  const ids = sections.map((s) => s.sectionId.trim());
  if (ids.some((id) => !id)) problems.push('Có phần học đang để trống mã.');
  if (new Set(ids).size !== ids.length) problems.push('Hai phần học trùng mã nhau.');
  if (sections.some((s) => !s.title.trim())) problems.push('Có phần học chưa được đặt tên.');
  const listed = sections.flatMap((s) => s.units);
  if (new Set(listed).size !== listed.length) problems.push('Một bài đang nằm ở hai phần học.');
  for (const theme of themes)
    if (!listed.includes(theme)) problems.push(`Bài “${theme}” chưa thuộc phần học nào.`);
  for (const theme of new Set(listed))
    if (!themes.includes(theme))
      problems.push(`Có phần học đang giữ bài “${theme}” nhưng khóa không còn bài đó.`);
  // The repo builder needs a section for every unit; how many sections a course has is a content
  // decision. The shipped vi_en path keeps its own floor in tools/content/lint-course.mjs.
  if (sections.length < 1) problems.push('Cần ít nhất 1 phần học để máy dựng chấp nhận bản xuất.');
  return problems;
}
