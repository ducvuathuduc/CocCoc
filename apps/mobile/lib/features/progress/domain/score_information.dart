class ScoreExample {
  const ScoreExample(this.english, this.vietnamese);
  final String english;
  final String vietnamese;
}

class ScoreBand {
  const ScoreBand({
    required this.label,
    required this.cefr,
    required this.description,
    this.examples = const <ScoreExample>[],
    this.locked = false,
  });
  final String label;
  final String cefr;
  final String description;
  final List<ScoreExample> examples;
  final bool locked;
}

const scoreBands = <ScoreBand>[
  ScoreBand(
    label: '0–9',
    cefr: 'very early A1',
    description: 'You can recognize a few familiar English words.',
    examples: [ScoreExample('Hello!', 'Xin chào!')],
  ),
  ScoreBand(
    label: '10–19',
    cefr: 'early A1',
    description: 'You can ask and answer simple everyday questions.',
    examples: [
      ScoreExample('My father is funny.', 'Bố tôi rất vui tính.'),
      ScoreExample('She has a lot of dogs!', 'Cô ấy có rất nhiều chó!'),
      ScoreExample(
        'Julia’s husband is Mexican.',
        'Chồng của Julia là người Mexico.',
      ),
    ],
  ),
  ScoreBand(
    label: '20–29',
    cefr: 'high A1',
    description:
        'You can use short sentences about people, places and routines.',
    examples: [
      ScoreExample('I take the bus every morning.', 'Tôi đi xe buýt mỗi sáng.'),
    ],
  ),
  ScoreBand(
    label: '30–59',
    cefr: 'A2',
    description:
        'You can handle common tasks and describe familiar experiences.',
    examples: [
      ScoreExample(
        'Could you tell me where the station is?',
        'Bạn có thể chỉ cho tôi nhà ga ở đâu không?',
      ),
    ],
  ),
  ScoreBand(
    label: '60–79',
    cefr: 'early B1',
    description: 'You can follow the main points of clear everyday English.',
    examples: [
      ScoreExample(
        'I changed my plans because the weather got worse.',
        'Tôi đã đổi kế hoạch vì thời tiết trở nên xấu hơn.',
      ),
    ],
  ),
  ScoreBand(
    label: '80–99',
    cefr: 'high B1',
    description:
        'You can explain opinions and understand detailed conversations.',
    examples: [
      ScoreExample(
        'Although the trip was tiring, it was worth the effort.',
        'Mặc dù chuyến đi mệt mỏi, nó rất đáng công sức.',
      ),
    ],
  ),
  ScoreBand(
    label: '100–114',
    cefr: 'early B2',
    description: 'You can discuss complex topics with clear supporting detail.',
    examples: [
      ScoreExample(
        'The proposal could succeed if the team addresses its risks.',
        'Đề xuất có thể thành công nếu nhóm xử lý các rủi ro.',
      ),
    ],
  ),
  ScoreBand(
    label: '115–129',
    cefr: 'high B2',
    description: 'You can communicate fluently across demanding situations.',
    examples: [
      ScoreExample(
        'Her argument was persuasive despite several unresolved assumptions.',
        'Lập luận của cô ấy thuyết phục dù còn vài giả định chưa được giải quyết.',
      ),
    ],
  ),
  ScoreBand(
    label: '130–160',
    cefr: 'C1 to C2',
    description:
        'You can understand nuanced ideas and express precise thoughts.',
    locked: true,
  ),
];

int scoreBandIndex(int score) {
  if (score < 10) return 0;
  if (score < 20) return 1;
  if (score < 30) return 2;
  if (score < 60) return 3;
  if (score < 80) return 4;
  if (score < 100) return 5;
  if (score < 115) return 6;
  if (score < 130) return 7;
  return 8;
}

const scoreBandStarts = <int>[0, 10, 20, 30, 60, 80, 100, 115, 130];
const scoreBandNext = <int>[10, 20, 30, 60, 80, 100, 115, 130, 160];
