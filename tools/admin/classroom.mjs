#!/usr/bin/env node
// Maintainer CLI: classrooms in Progress p_classrooms (P9-SOCIAL-002 join-by-code). The join code
// is stored only as a SHA-256 hash; the plaintext is printed once on create.
import { loadMaintainer, main, openStore } from './lib.mjs';

const usage = `usage: node tools/admin/classroom.mjs <command> [flags] [--memory] [--project <id>]
  create   --name <text> --teacher <appwriteUserId> [--course vi_en] [--code <CODE>]
  list     [--limit <n>]
  archive  --id <classroomId>`;

await main(async (command, flags) => {
  const kit = await loadMaintainer();
  const { store, target } = openStore(kit, flags);
  if (command === 'create') {
    if (typeof flags.name !== 'string' || typeof flags.teacher !== 'string') {
      throw new Error('--name and --teacher required');
    }
    const created = await kit.adminCreateClassroom(store, {
      name: flags.name,
      teacherUserId: flags.teacher,
      courseId: typeof flags.course === 'string' ? flags.course : 'vi_en',
      joinCode: typeof flags.code === 'string' ? flags.code : kit.randomCode('', 8),
    });
    return { target, ...created, note: 'join code shown once; only its hash is stored' };
  }
  if (command === 'list') {
    return { target, classrooms: await kit.adminListClassrooms(store, Number(flags.limit ?? 100)) };
  }
  if (command === 'archive') {
    if (typeof flags.id !== 'string') throw new Error('--id required');
    return { target, ...(await kit.adminArchiveClassroom(store, flags.id)) };
  }
  throw new Error(`unknown command ${command}`);
}, usage);
