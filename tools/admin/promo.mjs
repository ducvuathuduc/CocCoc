#!/usr/bin/env node
// Maintainer CLI: promo codes in Progress p_promo_codes (P10-PROMO-001). Codes are stored only
// as SHA-256 hashes; the plaintext is printed once on create. See tools/admin/lib.mjs for env.
import { loadMaintainer, main, openStore } from './lib.mjs';

const usage = `usage: node tools/admin/promo.mjs <command> [flags] [--memory] [--project <id>]
  create  --type GEMS --gems <n> | --type SUPER_DAYS --days <n> | --type ITEM --item <itemId> [--qty <n>]
          [--code <CODE> | --prefix <P>] [--max <n>] [--starts <ISO>] [--ends <ISO>] [--note <text>]
  list    [--limit <n>]
  pause | retire | activate  --code <CODE>`;

const int = (value, name) => {
  if (value === undefined) return undefined;
  const n = Number(value);
  if (!Number.isInteger(n)) throw new Error(`${name}: integer`);
  return n;
};

await main(async (command, flags) => {
  const kit = await loadMaintainer();
  const { store, target } = openStore(kit, flags);
  if (command === 'create') {
    const code =
      typeof flags.code === 'string' ? flags.code : kit.randomCode(flags.prefix || 'COC');
    const def = {
      code,
      rewardType: flags.type,
      superDays: int(flags.days, 'days'),
      gems: int(flags.gems, 'gems'),
      itemId: flags.item,
      itemQuantity: int(flags.qty, 'qty'),
      maxRedemptions: int(flags.max, 'max') ?? null,
      startsAt: flags.starts ?? new Date().toISOString(),
      endsAt: flags.ends ?? null,
      note: typeof flags.note === 'string' ? flags.note : null,
    };
    const { promoId, row } = await kit.adminCreatePromo(store, def);
    return {
      target,
      promoId,
      code,
      rewardType: row.rewardType,
      status: row.status,
      note: 'plaintext code shown once; only its hash is stored',
    };
  }
  if (command === 'list')
    return { target, promos: await kit.adminListPromos(store, int(flags.limit, 'limit') ?? 100) };
  const status = { pause: 'PAUSED', retire: 'RETIRED', activate: 'ACTIVE' }[command];
  if (status) {
    if (typeof flags.code !== 'string') throw new Error('--code required');
    return { target, ...(await kit.adminSetPromoStatus(store, flags.code, status)) };
  }
  throw new Error(`unknown command ${command}`);
}, usage);
