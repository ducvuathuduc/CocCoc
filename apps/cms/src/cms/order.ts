/** A unit row only needs its id and position to be reordered. */
export interface Positioned {
  unitId: string;
  order: number;
}

/**
 * Moves the item at `from` to `to`, keeping every other item in the same relative order. Positions are
 * dense (0..n-1) because `build-course.mjs:39` turns them into the `uNN` codes the app stores progress
 * against, so a gap would silently renumber the tail of the course.
 */
export function moveWithin<T>(items: T[], from: number, to: number): T[] {
  if (from < 0 || from >= items.length) throw new RangeError(`Vị trí ${from} không tồn tại.`);
  if (to < 0 || to >= items.length) throw new RangeError(`Vị trí ${to} không tồn tại.`);
  if (from === to) return [...items];
  const next = [...items];
  const [moved] = next.splice(from, 1);
  next.splice(to, 0, moved);
  return next;
}

/** New positions for the rows that actually change, in the order they should be written. */
export function orderChanges<T extends Positioned>(
  units: T[],
  from: number,
  to: number,
): { unit: T; order: number }[] {
  const ordered = moveWithin(units, from, to);
  return ordered
    .map((unit, index) => ({ unit, order: index }))
    .filter(({ unit, order }) => unit.order !== order);
}
