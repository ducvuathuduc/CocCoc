// Derive a correct (or deliberately wrong) wire answer from an authored exercise.
export function correctAnswer(exercise) {
  const rule = exercise.gradingRule;
  switch (exercise.type) {
    case 'textTranslation':
    case 'fillBlank':
    case 'dictation':
    case 'speakRepeat':
    case 'dialogueTurn':
      return { kind: 'text', text: rule.acceptedText[0] };
    case 'choice':
    case 'imageChoice':
    case 'listenChoice':
    case 'storyQuestion':
      return { kind: 'choice', choiceId: rule.correctChoiceId };
    case 'wordBank':
    case 'sentenceOrder':
      return { kind: 'tokens', tokenIds: rule.correctTokenIds };
    case 'matchPairs':
      return {
        kind: 'pairs',
        matches: exercise.content.pairs.map((p) => ({ leftId: p.left.id, rightId: p.right.id })),
      };
  }
  throw new Error(`no answer for ${exercise.type}`);
}
export function wrongAnswer(exercise) {
  const right = correctAnswer(exercise);
  switch (right.kind) {
    case 'text':
      return { kind: 'text', text: 'zzz wrong' };
    case 'choice':
      return {
        kind: 'choice',
        choiceId: exercise.content.choices.find((c) => c.id !== right.choiceId).id,
      };
    case 'tokens':
      return {
        kind: 'tokens',
        tokenIds:
          [...right.tokenIds].reverse().length > 1
            ? [...right.tokenIds].reverse()
            : exercise.content.tokens
                .filter((t) => t.id !== right.tokenIds[0])
                .slice(0, 1)
                .map((t) => t.id),
      };
    case 'pairs': {
      const p = exercise.content.pairs;
      return {
        kind: 'pairs',
        matches: p.map((x, i) => ({ leftId: x.left.id, rightId: p[(i + 1) % p.length].right.id })),
      };
    }
  }
}
