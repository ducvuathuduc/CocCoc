/**
 * How the billing tables are read out loud.
 *
 * The database stores enums (`SUPER`, `GRACE`, `PURCHASE`). A maintainer reading a learner's row needs a
 * Vietnamese word and, for the plan, a colour that matches the overview's bars — so the label and the
 * badge live together instead of each screen inventing its own.
 */
export const PLAN_LABEL: Record<string, string> = {
  FREE: 'Miễn phí',
  SUPER: 'Super',
  MAX: 'Max',
};

export const STATUS_LABEL: Record<string, string> = {
  ACTIVE: 'Đang dùng',
  GRACE: 'Gia hạn trễ',
  HOLD: 'Tạm giữ',
  CANCELED: 'Đã hủy',
  EXPIRED: 'Hết hạn',
  REVOKED: 'Thu hồi',
};

export const SOURCE_LABEL: Record<string, string> = {
  NONE: 'Không rõ',
  PURCHASE: 'Mua',
  FAMILY: 'Gói gia đình',
  GIFT: 'Quà tặng',
  TRIAL: 'Dùng thử',
  PROMO: 'Mã khuyến mãi',
  REFERRAL: 'Giới thiệu',
};

export const planLabel = (plan: string | null): string =>
  plan ? (PLAN_LABEL[plan] ?? plan) : 'Chưa có';

export const statusLabel = (status: string | null): string =>
  status ? (STATUS_LABEL[status] ?? status) : '—';

export const sourceLabel = (source: string): string => SOURCE_LABEL[source] ?? source;

/** Same three colours the overview uses for its bars, so a badge and a bar never disagree. */
export function planBadge(plan: string | null): string {
  if (plan === 'SUPER') return 'bg-primary-soft text-primary-text';
  if (plan === 'MAX') return 'bg-ok-bg text-ok-fg';
  return 'bg-elevated text-fg-3';
}

/** A plan only counts as paid while the row says it is still in force. */
export const isPaidActive = (plan: string | null, status: string | null): boolean =>
  (plan === 'SUPER' || plan === 'MAX') && status === 'ACTIVE';
