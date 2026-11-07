import { Suspense, ViewTransition } from 'react';
import { SidebarNav } from '@/components/sidebar-server';

// Every admin screen reads the session cookie and the draft store, so there is nothing to
// prerender: render the segment on the server instead of streaming an empty shell.
export const instant = false;

function PanelFallback({ height }: { height: string }) {
  return <div className={`skeleton rounded-3xl ${height}`} />;
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background text-fg">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:top-20 focus:left-4 focus:z-[60] focus:rounded-lg focus:border focus:border-line focus:bg-card focus:px-3 focus:py-2 focus:text-sm focus:shadow-lift"
      >
        Bỏ qua điều hướng
      </a>
      <Suspense fallback={<div className="skeleton h-16" />}>
        <SidebarNav />
      </Suspense>
      {/* The top bar and the rail are fixed chrome, so the content column simply
          starts below and beside them instead of nesting inside a flex row. */}
      <main id="main" tabIndex={-1} className="min-w-0 pt-16 outline-none lg:pl-14">
        <div className="mx-auto w-full max-w-[1240px] px-4 py-7 sm:px-6 lg:px-10 lg:py-9">
          <Suspense
            fallback={
              <ViewTransition exit="leave-up" default="none">
                <div className="rise space-y-4">
                  <PanelFallback height="h-24" />
                  <PanelFallback height="h-80" />
                  <div className="grid gap-4 lg:grid-cols-[1.4fr_1fr]">
                    <PanelFallback height="h-64" />
                    <PanelFallback height="h-64" />
                  </div>
                </div>
              </ViewTransition>
            }
          >
            <ViewTransition enter="enter-up" default="none">
              {children}
            </ViewTransition>
          </Suspense>
        </div>
      </main>
    </div>
  );
}
