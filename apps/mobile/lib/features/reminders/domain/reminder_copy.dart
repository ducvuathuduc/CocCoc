import 'reminder_models.dart';

/// One title/body pair. `{streak}`, `{next}` and `{friend}` are filled in.
class ReminderLine {
  const ReminderLine(this.title, this.body);
  final String title, body;
}

/// Streak lengths that get celebratory copy.
bool isStreakMilestone(int days) =>
    const {3, 7, 14, 30, 50, 100, 150, 200, 365}.contains(days) ||
    (days > 0 && days % 100 == 0);

/// Original Vietnamese notification copy with a playful mascot voice.
///
/// Rotation is deterministic: the variant for a kind on a given local day is
/// `(daySerial + salt) % pool.length`, so consecutive days never repeat a
/// line (pools have at least two lines) and a reschedule on the same day
/// never changes what the learner already saw.
abstract final class ReminderCopy {
  static const daily = <ReminderLine>[
    ReminderLine(
      'Đến giờ học rồi nè! 🐸',
      'Chỉ 5 phút thôi, mình đã chuẩn bị sẵn bài mới cho bạn.',
    ),
    ReminderLine(
      'Ê, bạn ơi! 👋',
      'Tiếng Anh đang chờ. Một bài nhỏ trước khi lướt mạng nhé?',
    ),
    ReminderLine(
      'Học một chút, giỏi thêm một chút ✨',
      'Bài hôm nay ngắn lắm, mở ra là xong ngay.',
    ),
    ReminderLine(
      'Mình nhớ bạn rồi đó 🥺',
      'Ghé học một bài để mình vui lại đi!',
    ),
    ReminderLine(
      'Hôm nay học gì ta? 🤔',
      'Vào xem bài tiếp theo trên lộ trình của bạn nhé.',
    ),
    ReminderLine(
      'Ting ting! Lời nhắc dễ thương tới đây 🔔',
      'Năm phút tiếng Anh, cả ngày tự tin.',
    ),
  ];

  static const dailyWithStreak = <ReminderLine>[
    ReminderLine(
      '🔥 {streak} ngày rồi đó!',
      'Học một bài để đưa chuỗi lên {next} ngày nào.',
    ),
    ReminderLine(
      'Ngọn lửa {streak} ngày đang đợi bạn 🔥',
      'Thêm củi cho lửa bằng một bài học ngắn nhé.',
    ),
    ReminderLine(
      'Đừng để chuỗi {streak} ngày nguội lạnh 🥶',
      'Một bài thôi là lửa lại bừng bừng!',
    ),
    ReminderLine(
      'Bạn đang làm rất tốt! 💪',
      'Chuỗi {streak} ngày, hôm nay là ngày thứ {next}.',
    ),
  ];

  static const comeback = <ReminderLine>[
    ReminderLine(
      'Lâu rồi không gặp! 👀',
      'Quay lại một bài thôi, mình hứa sẽ dễ thương.',
    ),
    ReminderLine(
      'Mình vẫn ở đây chờ bạn 🐸',
      'Bắt đầu lại chưa bao giờ là muộn. Một bài nhé?',
    ),
    ReminderLine(
      'Tiếng Anh của bạn nhớ bạn đó 💚',
      'Ôn lại chút xíu để không quên những gì đã học.',
    ),
  ];

  static const milestoneNext = <ReminderLine>[
    ReminderLine(
      'Chỉ một bài nữa là chạm mốc {next} ngày! 🏆',
      'Cột mốc lớn đang ở ngay trước mặt, học ngay thôi.',
    ),
    ReminderLine(
      'Mốc {next} ngày đang vẫy tay 🎯',
      'Hoàn thành một bài hôm nay để mở khóa nó.',
    ),
  ];

  static const milestoneReached = <ReminderLine>[
    ReminderLine(
      'Chuỗi {streak} ngày! Bạn đỉnh thật 🎉',
      'Giữ phong độ nào, hôm nay là ngày {next}.',
    ),
    ReminderLine(
      '{streak} ngày liên tục, quá xịn! 🔥',
      'Mình tự hào về bạn. Thêm một bài để tiếp tục nhé.',
    ),
  ];

  static const streakAtRisk = <ReminderLine>[
    ReminderLine(
      'Chuỗi {streak} ngày sắp tắt! 😱',
      'Còn kịp đó, học một bài trước nửa đêm nhé.',
    ),
    ReminderLine(
      'Cứu lửa! Cứu lửa! 🚒',
      'Chuỗi {streak} ngày của bạn cần một bài học ngay.',
    ),
    ReminderLine(
      'Mình không muốn thấy chuỗi này biến mất 🥺',
      '{streak} ngày công sức, chỉ cần 3 phút để giữ lại.',
    ),
    ReminderLine(
      'Lời nhắc cuối ngày ⏰',
      'Một bài nhanh thôi để chuỗi {streak} ngày tiếp tục cháy.',
    ),
  ];

  static const streakAtRiskWithFreeze = <ReminderLine>[
    ReminderLine(
      'Chuỗi {streak} ngày đang chờ bạn 🔥',
      'Băng giữ chuỗi có thể đỡ cho bạn, nhưng tự học vẫn vui hơn!',
    ),
    ReminderLine(
      'Đừng để Băng giữ chuỗi phải ra tay 🧊',
      'Một bài trước nửa đêm là chuỗi {streak} ngày an toàn.',
    ),
  ];

  static const friendStreak = <ReminderLine>[
    ReminderLine(
      '{friend} đang giữ chuỗi cùng bạn 🤝',
      'Học một bài để chuỗi bạn bè không bị đứt nhé.',
    ),
    ReminderLine(
      'Đồng đội đang chờ! 👯',
      '{friend} đã sẵn sàng. Còn bạn thì sao?',
    ),
    ReminderLine(
      'Chuỗi bạn bè cần bạn 💞',
      'Một bài nhỏ để giữ lời hứa với {friend}.',
    ),
  ];

  static const leagueEnding = <ReminderLine>[
    ReminderLine(
      'Giải đấu sắp khép lại! 🏁',
      'Vài giờ nữa là chốt bảng. Kiếm thêm XP để leo hạng nhé.',
    ),
    ReminderLine(
      'Nước rút cuối tuần 🏃',
      'Một bài nữa có thể đổi cả thứ hạng của bạn.',
    ),
    ReminderLine(
      'Bảng xếp hạng sắp chốt ⏳',
      'Giữ vững vị trí hoặc vượt lên, quyết định ngay bây giờ!',
    ),
  ];

  static const streakFreezeUsed = <ReminderLine>[
    ReminderLine(
      'Băng giữ chuỗi đã cứu bạn 🧊',
      'Chuỗi {streak} ngày vẫn an toàn. Hôm nay học tiếp nhé!',
    ),
    ReminderLine(
      'Phù, suýt nữa thì mất chuỗi! 😮‍💨',
      'Mình đã dùng Băng giữ chuỗi. Vào học để lửa cháy lại nào.',
    ),
  ];

  static const leaguePromoted = <ReminderLine>[
    ReminderLine(
      'Thăng hạng rồi! 🎉',
      'Bạn đã lên giải mới. Vào xem bảng xếp hạng nhé.',
    ),
    ReminderLine(
      'Quá đỉnh, bạn được thăng hạng! 🏆',
      'Tuần mới, giải mới, đối thủ mới. Sẵn sàng chưa?',
    ),
  ];

  static int _salt(ReminderKind kind) => kind.index * 7;

  /// Picks the line for [kind] on [daySerial] (days since 1970-01-01 of the
  /// local delivery date) and fills its placeholders.
  static ReminderLine pick(
    List<ReminderLine> pool,
    ReminderKind kind,
    int daySerial, {
    int streak = 0,
    String friend = '',
  }) {
    final line = pool[(daySerial + _salt(kind)) % pool.length];
    String fill(String s) => s
        .replaceAll('{streak}', '$streak')
        .replaceAll('{next}', '${streak + 1}')
        .replaceAll('{friend}', friend);
    return ReminderLine(fill(line.title), fill(line.body));
  }
}
