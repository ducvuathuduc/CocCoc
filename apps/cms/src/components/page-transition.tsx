import type { ReactNode } from 'react';
import { ViewTransition } from 'react';

// Direction carries meaning: lateral travel is reserved for going deeper into a
// course or coming back out of it, while switching top-level sections only
// lifts. Untyped commits (router.refresh, browser back) stay still.
const ENTER = {
  'nav-forward': 'nav-forward',
  'nav-back': 'nav-back',
  'nav-section': 'enter-up',
  default: 'none',
};

const EXIT = {
  'nav-forward': 'nav-forward',
  'nav-back': 'nav-back',
  'nav-section': 'leave-up',
  default: 'none',
};

export function PageTransition({ children }: { children: ReactNode }) {
  return (
    <ViewTransition enter={ENTER} exit={EXIT} default="none">
      {children}
    </ViewTransition>
  );
}
