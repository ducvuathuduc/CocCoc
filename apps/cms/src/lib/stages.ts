/**
 * The three workflow stages are rendered on the course home and on the check/publish screen. Colors
 * and state names live here so the two screens cannot describe the same state differently.
 */
export type StageState = 'waiting' | 'current' | 'done' | 'attention';

export const STAGE_STATE: Record<StageState, { box: string; dot: string; mark: string }> = {
  done: { box: 'border-ok-bd bg-ok-bg', dot: 'bg-ok-fg', mark: 'Xong' },
  current: { box: 'border-primary bg-primary-soft', dot: 'bg-primary', mark: 'Đang ở đây' },
  attention: { box: 'border-warn-bd bg-warn-bg', dot: 'bg-warn-fg', mark: 'Cần xử lý' },
  waiting: { box: 'border-line bg-card', dot: 'bg-line-strong', mark: 'Chưa tới' },
};
