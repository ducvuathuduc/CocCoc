import { Suspense, ViewTransition } from 'react';
import { SidebarNav } from '@/components/sidebar-server';

// Every admin screen reads the session cookie and the draft store, so there is nothing to
// prerender: render the segment on the server instead of streaming an empty shell.
export const instant = false;

function PanelFallback({ height }: { height: string }) {
  return <div className={`skeleton rounded-xl ${height}`} />;
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-background text-fg lg:flex-row">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:top-3 focus:left-4 focus:z-[60] focus:rounded-lg focus:border focus:border-line focus:bg-card focus:px-3 focus:py-2 focus:text-sm focus:shadow-lift"
      >
        Bỏ qua điều hướng
      </a>
      <Suspense fallback={<div className="skeleton h-14 shrink-0 lg:h-screen lg:w-64" />}>
        <SidebarNav />
      </Suspense>
      <main id="main" tabIndex={-1} className="min-w-0 flex-1 outline-none">
        <div className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          <Suspense
            fallback={
              <ViewTransition exit="leave-up" default="none">
                <div className="rise space-y-4">
                  <PanelFallback height="h-20" />
                  <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                    {[0, 1, 2, 3].map((key) => (
                      <PanelFallback key={key} height="h-24" />
                    ))}
                  </div>
                  <PanelFallback height="h-56" />
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
