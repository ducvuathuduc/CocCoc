'use client';

import { useState } from 'react';
import { toast } from 'sonner';
import { field, ghost, hint, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * A lesson is dozens of rows, and typing them one cell at a time is why nobody finishes one. This
 * lets an author write or paste the whole list in the same compact form the course files use, one
 * row per line, and adds them to the table. Nothing is saved until the author presses Lưu.
 */
export function PasteRows<T>({
  title,
  format,
  example,
  parse,
  onAdd,
}: {
  title: string;
  /** One sentence naming the shape of a line. */
  format: string;
  /** Lines shown as a placeholder, in the real shape. */
  example: string;
  parse: (text: string) => T[];
  onAdd: (rows: T[]) => void;
}) {
  const [text, setText] = useState('');
  const [problem, setProblem] = useState<string | null>(null);

  function add() {
    try {
      const rows = parse(text);
      if (rows.length === 0) {
        setProblem('Chưa có dòng nào để thêm.');
        return;
      }
      onAdd(rows);
      setText('');
      setProblem(null);
      toast.success(`Đã thêm ${rows.length} dòng vào bảng. Nhớ bấm Lưu.`);
    } catch (error) {
      const message = error instanceof Error ? error.message : '';
      const line = /"([^"]*)"\s*$/.exec(message)?.[1];
      setProblem(
        line
          ? `Dòng này chưa đúng dạng: “${line}”. ${format}`
          : `Có dòng chưa đúng dạng. ${format}`,
      );
    }
  }

  return (
    <details className="mb-3 rounded-lg border border-line bg-elevated/40 px-3 py-2">
      <summary className="cursor-pointer text-sm font-medium text-fg-2 hover:text-fg">
        {title}
      </summary>
      <p className={cn(hint, 'mt-2')}>{format}</p>
      <textarea
        aria-label={title}
        className={cn(field, 'mt-2 min-h-32 w-full font-mono text-xs leading-relaxed')}
        placeholder={example}
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          setProblem(null);
        }}
      />
      {problem && (
        <p role="alert" className="mt-2 text-xs text-warn-fg">
          {problem}
        </p>
      )}
      <div className="mt-2 flex items-center gap-2">
        <button type="button" className={primary} onClick={add} disabled={!text.trim()}>
          Thêm các dòng này
        </button>
        <button type="button" className={ghost} onClick={() => setText('')} disabled={!text}>
          Xóa ô này
        </button>
      </div>
    </details>
  );
}
