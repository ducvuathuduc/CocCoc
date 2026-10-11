import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../practice/data/journey_repository.dart' show englishRoleplay;
import '../domain/roleplay_models.dart';

abstract class RoleplayRepository {
  List<RoleplayTopic> topics();
  List<RoleplayScenario> scenariosFor(String topicId);
  RoleplayScenario? scenario(String id);

  /// Progress the learner already has when the app opens.
  Map<String, RoleplayProgress> initialProgress();

  /// Scenario shown in the library hero before the learner picks one.
  String defaultFeaturedId();
}

/// The original practice-hub restaurant roleplay. Its dialogue stays the
/// single source in [englishRoleplay] so the legacy entry point is unchanged.
const restaurantScenarioId = 'restaurant';

final _restaurantTips = [
  'To be more polite, you could say "Yes, please" when accepting food.',
  'To ask for water, you could say "Water, please."',
  'You can end politely with "Thank you!"',
];

final _restaurantHints = const [
  [RoleplayHint('vâng', 'Yes'), RoleplayHint('làm ơn', 'please')],
  [RoleplayHint('nước', 'Water'), RoleplayHint('một ly', 'a glass of')],
  [RoleplayHint('cảm ơn', 'Thank you'), RoleplayHint('rất', 'very much')],
];

class MockRoleplayRepository implements RoleplayRepository {
  const MockRoleplayRepository();

  static const _topics = [
    RoleplayTopic(id: 'daily', title: 'Daily Life'),
    RoleplayTopic(id: 'travel', title: 'Travel'),
    RoleplayTopic(id: 'food', title: 'Food & Shopping'),
    RoleplayTopic(id: 'hobbies', title: 'Hobbies & Leisure'),
    RoleplayTopic(id: 'work', title: 'Work & School'),
    RoleplayTopic(id: 'around', title: 'Getting Around'),
    RoleplayTopic(id: 'friends', title: 'Friends & Family'),
    RoleplayTopic(id: 'yourself', title: 'Talk About Yourself'),
  ];

  static final List<RoleplayScenario> _scenarios = [
    RoleplayScenario(
      id: restaurantScenarioId,
      topicId: 'food',
      title: 'Dine at a restaurant',
      setting: 'You are dining at a restaurant in London. Lily approaches your table to share the special of the day.',
      wellDone: 'Well done ordering in English! You’ve made a great choice with the chicken and a glass of water.',
      takeaway: 'Use “please” to make an English request polite.',
      pattern: '[request] + please',
      example: 'Water, please.',
      scene: RoleplayScene.restaurant,
      lines: [
        for (var i = 0; i < englishRoleplay.length; i++)
          RoleplayLine(
            prompt: englishRoleplay[i].$1,
            translation: englishRoleplay[i].$2,
            hints: _restaurantHints[i],
            tip: _restaurantTips[i],
          ),
      ],
    ),
    const RoleplayScenario(
      id: 'market',
      topicId: 'food',
      title: 'Buy fruit at the market',
      setting: 'You stop at a fruit stall on your way home. Lily is selling fresh mangoes today.',
      wellDone: 'Well done shopping in English! You got your mangoes at a good price.',
      takeaway: 'Use “How much…?” to ask about prices.',
      pattern: 'How much + is/are + [item]?',
      example: 'How much are the mangoes?',
      scene: RoleplayScene.restaurant,
      lines: [
        RoleplayLine(
          prompt: 'Hi! What would you like today?',
          translation: 'Chào bạn! Hôm nay bạn muốn mua gì?',
          hints: [
            RoleplayHint('tôi muốn', 'I would like'),
            RoleplayHint('xoài', 'some mangoes'),
          ],
          tip: 'Start with "I would like…" to sound friendly.',
        ),
        RoleplayLine(
          prompt: 'Sure. How many do you need?',
          translation: 'Được. Bạn cần bao nhiêu quả?',
          hints: [
            RoleplayHint('ba', 'three'),
            RoleplayHint('bao nhiêu tiền', 'How much'),
          ],
          tip: 'You can ask the price with "How much are they?"',
        ),
        RoleplayLine(
          prompt: 'That’s four dollars, please.',
          translation: 'Của bạn là bốn đô-la.',
          hints: [
            RoleplayHint('đây', 'Here you are'),
            RoleplayHint('cảm ơn', 'thanks'),
          ],
          tip: 'Say "Here you are" when you hand over money.',
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'airport',
      topicId: 'travel',
      title: 'Make it to the airport on time',
      setting: 'You’re rushing to catch a flight and need a bus ticket at the station where Lily works.',
      wellDone: 'Well done securing your bus ticket swiftly! Lily’s help got you one step closer to your flight. Safe travels!',
      takeaway: 'Use “I’m going to…” to say where you are going.',
      pattern: 'I’m going to + [place]',
      example: 'I’m going to the airport.',
      lines: [
        RoleplayLine(
          prompt: 'Hello, where are you going?',
          translation: 'Xin chào, bạn đi đâu?',
          hints: [
            RoleplayHint('tàu hỏa', 'a train'),
            RoleplayHint('đến sân bay', 'to the airport'),
            RoleplayHint('tôi đang đi', 'I’m going'),
          ],
          tip: 'Well done using "I’m going" to say where you’re going!',
        ),
        RoleplayLine(
          prompt: 'A ticket to the airport, right?',
          translation: 'Một vé đến sân bay, đúng không?',
          hints: [
            RoleplayHint('vâng', 'Yes'),
            RoleplayHint('vé máy bay', 'a plane ticket'),
            RoleplayHint('cho', 'for'),
          ],
          tip: 'To clarify, you could say "to the airport".',
        ),
        RoleplayLine(
          prompt: 'A bus ticket, not a plane ticket. How will you pay?',
          translation: 'Vé xe buýt, không phải vé máy bay. Bạn trả bằng gì?',
          hints: [
            RoleplayHint('tiền mặt', 'in cash'),
            RoleplayHint('bằng thẻ', 'by card'),
          ],
          tip: 'To add politeness, you could say "please".',
        ),
        RoleplayLine(
          prompt: 'Okay. Here is your ticket. Have a good trip!',
          translation: 'Được rồi. Vé của bạn đây. Chúc chuyến đi vui vẻ!',
          hints: [
            RoleplayHint('cảm ơn', 'Thank you'),
            RoleplayHint('tạm biệt', 'Goodbye'),
          ],
          tip: 'A short "Thank you, goodbye!" ends the talk nicely.',
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'hotel',
      topicId: 'travel',
      title: 'Check in at a hotel',
      setting: 'You arrive late at your hotel. Lily is at the front desk.',
      wellDone: 'Well done checking in! Your room is ready. Sleep well!',
      takeaway: 'Use “I have a reservation” when you arrive.',
      pattern: 'I have a reservation + for/under + [name]',
      example: 'I have a reservation under Nguyen.',
      lines: [
        RoleplayLine(
          prompt: 'Good evening! How can I help you?',
          translation: 'Chào buổi tối! Tôi có thể giúp gì cho bạn?',
          hints: [RoleplayHint('đặt phòng', 'a reservation')],
          tip: 'Say "I have a reservation" to start check-in.',
        ),
        RoleplayLine(
          prompt: 'What name is it under?',
          translation: 'Đặt phòng dưới tên gì?',
          hints: [RoleplayHint('tên tôi là', 'My name is')],
          tip: 'You can say "It’s under…" with your name.',
        ),
        RoleplayLine(
          prompt: 'Here is your key. Breakfast is at seven.',
          translation: 'Chìa khóa của bạn đây. Bữa sáng lúc bảy giờ.',
          hints: [RoleplayHint('tuyệt', 'Great')],
          tip: 'Thank the receptionist before you go.',
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'morning',
      topicId: 'daily',
      title: 'Plan your morning',
      setting: 'Lily is your roommate. She asks about your plans for today.',
      wellDone: 'Well done talking about your day! You have a busy morning.',
      takeaway: 'Use “I usually…” to talk about routines.',
      pattern: 'I usually + [verb]',
      example: 'I usually drink coffee.',
      lines: [
        RoleplayLine(
          prompt: 'Good morning! What time did you wake up?',
          translation: 'Chào buổi sáng! Bạn dậy lúc mấy giờ?',
          hints: [RoleplayHint('lúc bảy giờ', 'at seven')],
        ),
        RoleplayLine(
          prompt: 'What do you usually eat for breakfast?',
          translation: 'Bạn thường ăn sáng món gì?',
          hints: [RoleplayHint('tôi thường', 'I usually')],
        ),
        RoleplayLine(
          prompt: 'Nice! What are you doing this morning?',
          translation: 'Hay quá! Sáng nay bạn làm gì?',
          hints: [RoleplayHint('đi học', 'go to class')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'neighbor',
      topicId: 'daily',
      title: 'Meet your new neighbor',
      setting: 'Lily just moved in next door and knocks to say hello.',
      wellDone: 'Well done making a new friend next door!',
      takeaway: 'Use “Nice to meet you” when you meet someone.',
      pattern: 'Nice to meet you, + [name]',
      example: 'Nice to meet you, Lily.',
      lines: [
        RoleplayLine(
          prompt: 'Hi! I’m Lily. I just moved in.',
          translation: 'Chào! Mình là Lily. Mình mới chuyển đến.',
          hints: [RoleplayHint('rất vui được gặp', 'Nice to meet you')],
        ),
        RoleplayLine(
          prompt: 'How long have you lived here?',
          translation: 'Bạn sống ở đây bao lâu rồi?',
          hints: [RoleplayHint('hai năm', 'for two years')],
        ),
        RoleplayLine(
          prompt: 'Do you know a good café nearby?',
          translation: 'Bạn có biết quán cà phê nào ngon gần đây không?',
          hints: [RoleplayHint('gần', 'near')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'movie',
      topicId: 'hobbies',
      title: 'Pick a movie with a friend',
      setting: 'It’s Friday night. Lily wants to watch a movie with you.',
      wellDone: 'Well done! You picked a great movie for tonight.',
      takeaway: 'Use “How about…?” to make a suggestion.',
      pattern: 'How about + [noun / verb-ing]?',
      example: 'How about a comedy?',
      lines: [
        RoleplayLine(
          prompt: 'Do you want to watch a movie tonight?',
          translation: 'Tối nay bạn muốn xem phim không?',
          hints: [RoleplayHint('chắc chắn rồi', 'Sure')],
        ),
        RoleplayLine(
          prompt: 'What kind of movies do you like?',
          translation: 'Bạn thích thể loại phim nào?',
          hints: [RoleplayHint('phim hài', 'comedies')],
        ),
        RoleplayLine(
          prompt: 'Great! Let’s meet at eight.',
          translation: 'Tuyệt! Gặp nhau lúc tám giờ nhé.',
          hints: [RoleplayHint('hẹn gặp', 'See you')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'interview',
      topicId: 'work',
      title: 'Answer a job interview question',
      setting: 'Lily is interviewing you for a part-time job at her café.',
      wellDone: 'Well done! Lily was impressed by your answers.',
      takeaway: 'Use “I’m good at…” to talk about skills.',
      pattern: 'I’m good at + [noun / verb-ing]',
      example: 'I’m good at working with people.',
      lines: [
        RoleplayLine(
          prompt: 'Thanks for coming. Tell me about yourself.',
          translation: 'Cảm ơn bạn đã đến. Hãy giới thiệu về bản thân.',
          hints: [RoleplayHint('tôi là sinh viên', 'I’m a student')],
        ),
        RoleplayLine(
          prompt: 'What are you good at?',
          translation: 'Bạn giỏi việc gì?',
          hints: [RoleplayHint('tôi giỏi', 'I’m good at')],
        ),
        RoleplayLine(
          prompt: 'When can you start?',
          translation: 'Khi nào bạn có thể bắt đầu?',
          hints: [RoleplayHint('thứ Hai tới', 'next Monday')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'directions',
      topicId: 'around',
      title: 'Ask for directions',
      setting: 'You are lost downtown. Lily is waiting at the bus stop.',
      wellDone: 'Well done! You found your way to the museum.',
      takeaway: 'Use “Where is…?” to ask for a place.',
      pattern: 'Excuse me, where is + [place]?',
      example: 'Excuse me, where is the museum?',
      lines: [
        RoleplayLine(
          prompt: 'You look lost. Can I help?',
          translation: 'Bạn có vẻ bị lạc. Tôi giúp được không?',
          hints: [RoleplayHint('ở đâu', 'Where is')],
        ),
        RoleplayLine(
          prompt: 'Go straight and turn left at the bank.',
          translation: 'Đi thẳng rồi rẽ trái ở ngân hàng.',
          hints: [RoleplayHint('có xa không', 'Is it far')],
        ),
        RoleplayLine(
          prompt: 'It’s about five minutes on foot.',
          translation: 'Đi bộ khoảng năm phút.',
          hints: [RoleplayHint('cảm ơn', 'Thank you')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'party',
      topicId: 'friends',
      title: 'Plan a birthday party',
      setting: 'Your brother’s birthday is soon. Lily helps you plan a party.',
      wellDone: 'Well done! The party plan is ready.',
      takeaway: 'Use “Let’s…” to suggest doing something together.',
      pattern: 'Let’s + [verb]',
      example: 'Let’s buy a cake.',
      lines: [
        RoleplayLine(
          prompt: 'When is the birthday party?',
          translation: 'Tiệc sinh nhật khi nào?',
          hints: [RoleplayHint('thứ Bảy', 'on Saturday')],
        ),
        RoleplayLine(
          prompt: 'Who are you going to invite?',
          translation: 'Bạn sẽ mời ai?',
          hints: [RoleplayHint('bạn bè', 'our friends')],
        ),
        RoleplayLine(
          prompt: 'What food should we get?',
          translation: 'Chúng ta nên mua đồ ăn gì?',
          hints: [RoleplayHint('chúng ta hãy', 'Let’s')],
        ),
      ],
    ),
    const RoleplayScenario(
      id: 'intro',
      topicId: 'yourself',
      title: 'Introduce yourself',
      setting: 'It’s the first day of English class. Lily is your classmate.',
      wellDone: 'Well done introducing yourself!',
      takeaway: 'Use “I’m from…” to say where you come from.',
      pattern: 'I’m from + [place]',
      example: 'I’m from Vietnam.',
      lines: [
        RoleplayLine(
          prompt: 'Hi! What’s your name?',
          translation: 'Chào! Bạn tên gì?',
          hints: [RoleplayHint('tên tôi là', 'My name is')],
        ),
        RoleplayLine(
          prompt: 'Where are you from?',
          translation: 'Bạn đến từ đâu?',
          hints: [RoleplayHint('tôi đến từ', 'I’m from')],
        ),
        RoleplayLine(
          prompt: 'Why are you learning English?',
          translation: 'Tại sao bạn học tiếng Anh?',
          hints: [RoleplayHint('cho công việc', 'for work')],
        ),
      ],
    ),
  ];

  @override
  List<RoleplayTopic> topics() => _topics;

  @override
  List<RoleplayScenario> scenariosFor(String topicId) =>
      _scenarios.where((s) => s.topicId == topicId).toList(growable: false);

  @override
  RoleplayScenario? scenario(String id) {
    for (final s in _scenarios) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Map<String, RoleplayProgress> initialProgress() => const {
    restaurantScenarioId: RoleplayProgress(
      stars: 2,
      bestWords: 13,
      completions: 1,
    ),
  };

  @override
  String defaultFeaturedId() => restaurantScenarioId;
}

final roleplayRepositoryProvider = Provider<RoleplayRepository>(
  (ref) => const MockRoleplayRepository(),
);
