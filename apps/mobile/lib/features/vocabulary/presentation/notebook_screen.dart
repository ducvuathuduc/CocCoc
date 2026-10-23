import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notebook_controller.dart';
import '../domain/vocabulary_card.dart';
import '../../auth/application/auth_controller.dart';

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});
  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  bool busy = false;
  String? error;
  Future<void> command(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save changes. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(notebookProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My vocabulary'),
        actions: [
          IconButton(
            tooltip: 'Refresh due words',
            onPressed: () => ref.invalidate(notebookProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: cards.when(
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notebookProvider),
            child: const Text('Cannot load notebook. Retry'),
          ),
        ),
        data: (items) {
          final sorted = [...items]
            ..sort((a, b) {
              final byDate = a.dueAt.compareTo(b.dueAt);
              return byDate != 0 ? byDate : a.id.compareTo(b.id);
            });
          final due = sorted.where((v) => v.isDue(DateTime.now())).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Saved on this device for this account and course. Reviews use UTC days and do not award XP.',
              ),
              const SizedBox(height: 12),
              Text('${items.length} saved · ${due.length} due'),
              if (error != null) Text(error!, semanticsLabel: error),
              FilledButton(
                onPressed: busy || due.isEmpty
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VocabularyReviewScreen(
                              cards: due.take(20).toList(),
                            ),
                          ),
                        );
                        if (mounted) ref.invalidate(notebookProvider);
                      },
                child: const Text('REVIEW DUE WORDS'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => editVocabulary(context),
                child: const Text('ADD WORD OR PHRASE'),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your notebook is empty. Save words here or after answering a lesson.',
                  ),
                ),
              for (final card in sorted)
                ListTile(
                  title: Text(card.term),
                  subtitle: Text(
                    '${card.meaning}${card.example.isEmpty ? '' : '\n${card.example}'}\nStage ${card.stage} · Due ${card.dueAt.toIso8601String().substring(0, 10)} UTC',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Remove ${card.term}',
                    onPressed: busy
                        ? null
                        : () => command(
                            () => ref
                                .read(notebookProvider.notifier)
                                .run((r) => r.remove(card.id)),
                          ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> editVocabulary(
  BuildContext context, {
  String term = '',
  String meaning = '',
  String example = '',
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _VocabularyEditor(term: term, meaning: meaning, example: example),
);

class _VocabularyEditor extends ConsumerStatefulWidget {
  const _VocabularyEditor({
    required this.term,
    required this.meaning,
    required this.example,
  });
  final String term, meaning, example;
  @override
  ConsumerState<_VocabularyEditor> createState() => _VocabularyEditorState();
}

class _VocabularyEditorState extends ConsumerState<_VocabularyEditor> {
  late final term = TextEditingController(text: widget.term);
  late final meaning = TextEditingController(text: widget.meaning);
  late final example = TextEditingController(text: widget.example);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    term.dispose();
    meaning.dispose();
    example.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((s) => s.user?.id), (
      previous,
      next,
    ) {
      if (previous != next && mounted) Navigator.of(context).pop();
    });
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Save vocabulary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: term,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'English word or phrase',
                ),
              ),
              TextField(
                controller: meaning,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Vietnamese meaning',
                ),
              ),
              TextField(
                controller: example,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Example (optional)',
                ),
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    VocabularyCard card;
                    try {
                      card = VocabularyCard.create(
                        term.text,
                        meaning.text,
                        example.text,
                        DateTime.now(),
                      );
                    } on ArgumentError {
                      setState(
                        () => error = 'Enter a word/phrase and its meaning.',
                      );
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(notebookProvider.notifier)
                          .run((r) => r.save(card));
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = 'Could not save. Please retry.';
                        });
                      }
                    }
                  },
            child: Text(busy ? 'SAVING…' : 'SAVE'),
          ),
        ],
      ),
    );
  }
}

class VocabularyReviewScreen extends ConsumerStatefulWidget {
  const VocabularyReviewScreen({super.key, required this.cards});
  final List<VocabularyCard> cards;
  @override
  ConsumerState<VocabularyReviewScreen> createState() =>
      _VocabularyReviewScreenState();
}

class _VocabularyReviewScreenState
    extends ConsumerState<VocabularyReviewScreen> {
  final answer = TextEditingController();
  int index = 0;
  bool assisted = false, busy = false, checked = false;
  String? message;
  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = index < widget.cards.length ? widget.cards[index] : null;
    // Changing accounts must never leave the previous account's cards visible.
    ref.listen(notebookRepositoryProvider, (previous, next) {
      if (previous?.value != null &&
          !identical(previous?.value, next.value) &&
          mounted) {
        Navigator.of(context).pop();
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (card == null) ...[
            const Text(
              'Review complete. Your next reviews have been scheduled. No XP awarded.',
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('DONE'),
            ),
          ] else ...[
            Text('${index + 1} / ${widget.cards.length}'),
            Text(card.term, style: Theme.of(context).textTheme.headlineMedium),
            const Text('Type the saved Vietnamese meaning. Accents matter.'),
            TextField(
              controller: answer,
              enabled: !busy && !checked,
              decoration: const InputDecoration(labelText: 'Meaning'),
            ),
            TextButton(
              onPressed: checked || busy
                  ? null
                  : () => setState(() {
                      assisted = true;
                      message = 'Hint: ${card.meaning.characters.first}…';
                    }),
              child: const Text('HINT'),
            ),
            if (message != null) Text(message!),
            if (!checked)
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (answer.text.trim().isEmpty) {
                          setState(() => message = 'Enter an answer first.');
                          return;
                        }
                        setState(() => busy = true);
                        final correct = card.matchesMeaning(answer.text);
                        try {
                          await ref
                              .read(notebookProvider.notifier)
                              .run(
                                (r) => r.review(
                                  card.id,
                                  DateTime.now(),
                                  correct: correct,
                                  assisted: assisted,
                                ),
                              );
                          if (mounted) {
                            setState(() {
                              checked = true;
                              message =
                                  '${correct ? 'Correct' : 'Answer: ${card.meaning}'}${card.example.isEmpty ? '' : '\n${card.example}'}\n${!correct || assisted ? 'Review tomorrow (stage reset).' : 'Next interval scheduled.'}';
                            });
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => message = 'Could not save review. Retry or return to notebook.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(busy ? 'SAVING…' : 'CHECK'),
              ),
            if (checked)
              FilledButton(
                onPressed: () => setState(() {
                  index++;
                  checked = false;
                  assisted = false;
                  message = null;
                  answer.clear();
                }),
                child: const Text('NEXT'),
              ),
          ],
        ],
      ),
    );
  }
}
