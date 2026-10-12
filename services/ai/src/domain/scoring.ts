// Server-computed conversation result (completeConversation): stars, XP and feedback come only
// from turns the server recorded, never from the client.
import type { Scenario } from './scenarios.js';

export interface TurnTally {
  turnCount: number;
  onTopicTurns: number;
  usedWords: string[];
}

export interface ConversationResult {
  stars: number;
  xp: number;
  wordsUsed: number;
  feedback: {
    summary: string;
    strengths: string[];
    improvements: string[];
    usedWords: string[];
  };
}

/** XP for a completed conversation: 5 base + 5 per star (max 20; event schema allows <= 100). */
export function xpForStars(stars: number): number {
  return 5 + 5 * stars;
}

export function scoreConversation(scenario: Scenario, tally: TurnTally): ConversationResult {
  const steps = scenario.steps.length;
  const words = [...new Set(tally.usedWords)].slice(0, 60);
  const wordGoal = Math.ceil(scenario.targetWords.length / 2);
  let stars = 1;
  if (tally.onTopicTurns >= steps) stars++;
  if (words.length >= wordGoal) stars++;
  const strengths: string[] = [];
  const improvements: string[] = [];
  if (tally.onTopicTurns >= steps) strengths.push('You answered every question on topic.');
  else improvements.push('Answer each question with the key words from the conversation.');
  if (words.length >= wordGoal) strengths.push(`You used ${words.length} useful words.`);
  else
    improvements.push(
      `Try to use more of these words: ${scenario.targetWords
        .filter((w) => !words.includes(w))
        .slice(0, 4)
        .join(', ')}.`,
    );
  strengths.push(`You finished "${scenario.title}".`);
  return {
    stars,
    xp: xpForStars(stars),
    wordsUsed: words.length,
    feedback: {
      summary:
        stars === 3
          ? `Excellent! You completed "${scenario.title}" with ${scenario.partnerName}.`
          : `Good job! You completed "${scenario.title}" with ${scenario.partnerName}. Keep practicing.`,
      strengths: strengths.slice(0, 5),
      improvements: improvements.slice(0, 5),
      usedWords: words,
    },
  };
}
