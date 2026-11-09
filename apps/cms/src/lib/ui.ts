/* Shared surface + motion presets. Every screen reads these tokens, so a
   palette or timing change lands in one file instead of 250 class strings. */

export const field =
  'w-full rounded-lg border border-line bg-input-bg px-3 py-2 text-sm text-fg outline-none placeholder:text-fg-4 hover:border-line-strong focus:border-primary focus:ring-2 focus:ring-ring';
export const compact =
  'w-full rounded-md border border-line bg-input-bg px-2 py-1 text-sm text-fg outline-none placeholder:text-fg-4 hover:border-line-strong focus:border-primary focus:ring-2 focus:ring-ring';
export const button =
  'rounded-lg border border-line-strong bg-card px-3 py-2 text-sm text-fg-2 shadow-card hover:-translate-y-px hover:border-primary/40 hover:bg-primary-soft hover:text-primary-text active:translate-y-0 active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50';
export const primary =
  'rounded-lg bg-primary px-3 py-2 text-sm font-medium text-primary-fg shadow-card hover:-translate-y-px hover:bg-primary-hover hover:shadow-lift active:translate-y-0 active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50';
export const ghost =
  'rounded-md px-2 py-1 text-xs text-fg-3 hover:bg-primary-soft hover:text-primary-text disabled:opacity-40';
export const danger =
  'rounded-md px-2 py-1 text-xs text-fg-3 hover:bg-danger-bg hover:text-danger-fg disabled:opacity-40';
export const card = 'rounded-xl border border-line bg-card shadow-card';
/* The big borderless surfaces of the overview: on the grey page background a
   shadow alone reads as a card, so a border would only add noise. */
export const panel = 'rounded-3xl bg-card shadow-card';
/* Circular initials button for the account control in the top bar. */
export const circle =
  'relative flex size-10 shrink-0 items-center justify-center rounded-full bg-card text-fg-2 shadow-card hover:-translate-y-px hover:text-fg hover:shadow-lift disabled:pointer-events-none disabled:opacity-50';
export const link =
  'text-primary-text underline-offset-4 transition-colors hover:text-primary hover:underline';
export const badge =
  'rounded-full bg-primary-soft px-2 py-0.5 text-xs font-medium text-primary-text';
export const log =
  'rounded-lg border border-line bg-elevated p-3 font-mono text-xs leading-relaxed text-fg-3';
export const code = 'rounded bg-elevated px-1 py-0.5 font-mono text-[0.8em] text-fg-2';
export const warnBox = 'rounded-xl border border-warn-bd bg-warn-bg px-4 py-3 text-sm text-warn-fg';
export const row = 'transition-colors hover:bg-elevated';
export const tile =
  'rounded-xl border border-line bg-card px-4 py-3 shadow-card transition-[box-shadow,transform] hover:-translate-y-px hover:shadow-lift';
export const th = 'px-2 py-2 text-left text-xs font-medium text-fg-3';
export const td = 'px-2 py-1 align-top';

/* Sizes and microcopy for people who are not scanning a dashboard — they are deciding what to do next.
   `big` is combined with `primary`/`button` to give the one action on a screen a real touch target, and
   `hint` is the plain sentence under a heading: inline on purpose, because hovering is not a discoverable
   affordance for a non-technical operator. */
export const big = 'min-h-11 gap-2 rounded-xl px-5 py-2.5 text-sm';
export const hint = 'text-xs leading-relaxed text-fg-4';
export const quiet =
  'rounded-lg border border-line bg-transparent px-3 py-2 text-sm text-fg-3 transition-colors hover:border-line-strong hover:bg-elevated hover:text-fg disabled:pointer-events-none disabled:opacity-50';
