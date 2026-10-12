// vi_en v2 — "Tiếng Anh cho người Việt": a CEFR A1 -> A2 path in Duolingo structure.
// Authored tables live in ./units/*.mjs; tools/content/build-course.mjs generates the signed course
// (content/vi_en/next/v2). Edit tables, then rebuild + lint; never hand-edit generated JSON.
//
// Cast (own characters, recurring across units and stories):
//   Mai   — cheerful Vietnamese university student in Ho Chi Minh City (main learner avatar)
//   Nam   — Mai's classmate, loves football and food
//   Linh  — Mai's older cousin, works in an office
//   Tom   — exchange student from Canada; Anna is his sister
//   Mr. Long — the English teacher; Mrs. Rosa — owns the café near the school
//   Kiko  — Mai's lazy orange cat
import * as u01 from './units/u01-greetings.mjs';
import * as u02 from './units/u02-family.mjs';
import * as u03 from './units/u03-food.mjs';
import * as u04 from './units/u04-numbers.mjs';
import * as u05 from './units/u05-time.mjs';
import * as u06 from './units/u06-home.mjs';
import * as u07 from './units/u07-school.mjs';
import * as u08 from './units/u08-weather.mjs';
import * as u09 from './units/u09-shopping.mjs';
import * as u10 from './units/u10-directions.mjs';
import * as u11 from './units/u11-travel.mjs';
import * as u12 from './units/u12-work.mjs';
import * as u13 from './units/u13-hobbies.mjs';
import * as u14 from './units/u14-health.mjs';
import * as u15 from './units/u15-feelings.mjs';
import * as u16 from './units/u16-plans.mjs';

export const course = {
  courseId: 'vi_en',
  title: 'Tiếng Anh cho người Việt',
  sourceLocale: 'vi-VN',
  targetLocale: 'en-US',
};

export const sections = [
  {
    sectionId: 'sec1',
    title: 'Phần 1: Nền tảng (A1)',
    units: ['greetings', 'family', 'food', 'numbers', 'time', 'home', 'school', 'weather'],
  },
  {
    sectionId: 'sec2',
    title: 'Phần 2: Cuộc sống hằng ngày (A2)',
    units: ['shopping', 'directions', 'travel', 'work', 'hobbies', 'health', 'feelings', 'plans'],
  },
];

export const unitModules = [
  u01,
  u02,
  u03,
  u04,
  u05,
  u06,
  u07,
  u08,
  u09,
  u10,
  u11,
  u12,
  u13,
  u14,
  u15,
  u16,
];
