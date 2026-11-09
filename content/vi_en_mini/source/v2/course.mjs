// vi_en_mini v2 — the same tables as v1, published under a second version id. It exists so the
// multi-course tests can prove version isolation: two versions of one course live side by side with
// distinct fileIds, lessonVersion prefixes and published pointers.
export { course, sections, unitModules } from '../v1/course.mjs';
