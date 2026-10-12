import '../domain/practice_models.dart';

abstract class PracticeRepository {
  List<PracticeWord> loadWords();
}

/// Open server mistakes (exercise ids; prompts live in lesson bundles).
class PracticeMistake {
  const PracticeMistake({
    required this.exerciseId,
    required this.skillId,
    required this.count,
  });

  final String exerciseId;
  final String skillId;
  final int count;
}

/// Optional read an API-backed [PracticeRepository] also implements.
abstract interface class PracticeMistakes {
  List<PracticeMistake> loadMistakes();
}

class MockPracticeRepository implements PracticeRepository, PracticeMistakes {
  const MockPracticeRepository({this.words = mockPracticeWords});

  /// The four words of the archived reference account (golden fixtures).
  MockPracticeRepository.reference()
    : words = mockPracticeWords.take(4).toList();

  final List<PracticeWord> words;

  @override
  List<PracticeWord> loadWords() => words;

  @override
  List<PracticeMistake> loadMistakes() => mockPracticeMistakes;
}

/// Saved words, newest first (Words screen). English term, Vietnamese meaning.
const mockPracticeWords = <PracticeWord>[
  PracticeWord(id: 'woman', term: 'woman', meaning: 'người phụ nữ'),
  PracticeWord(id: 'hello', term: 'hello', meaning: 'xin chào'),
  PracticeWord(id: 'bear', term: 'bear', meaning: 'con gấu'),
  PracticeWord(id: 'thank-you', term: 'thank you', meaning: 'cảm ơn'),
  PracticeWord(id: 'goodbye', term: 'goodbye', meaning: 'tạm biệt'),
  PracticeWord(id: 'please', term: 'please', meaning: 'làm ơn'),
  PracticeWord(id: 'sorry', term: 'sorry', meaning: 'xin lỗi'),
  PracticeWord(id: 'yes', term: 'yes', meaning: 'vâng'),
  PracticeWord(id: 'no', term: 'no', meaning: 'không'),
  PracticeWord(id: 'man', term: 'man', meaning: 'người đàn ông'),
  PracticeWord(id: 'boy', term: 'boy', meaning: 'cậu bé'),
  PracticeWord(id: 'girl', term: 'girl', meaning: 'cô bé'),
  PracticeWord(id: 'cat', term: 'cat', meaning: 'con mèo'),
  PracticeWord(id: 'dog', term: 'dog', meaning: 'con chó'),
  PracticeWord(id: 'bird', term: 'bird', meaning: 'con chim'),
  PracticeWord(id: 'fish', term: 'fish', meaning: 'con cá'),
  PracticeWord(id: 'apple', term: 'apple', meaning: 'quả táo'),
  PracticeWord(id: 'banana', term: 'banana', meaning: 'quả chuối'),
  PracticeWord(id: 'orange', term: 'orange', meaning: 'quả cam'),
  PracticeWord(id: 'bread', term: 'bread', meaning: 'bánh mì'),
  PracticeWord(id: 'rice', term: 'rice', meaning: 'cơm'),
  PracticeWord(id: 'water', term: 'water', meaning: 'nước'),
  PracticeWord(id: 'milk', term: 'milk', meaning: 'sữa'),
  PracticeWord(id: 'coffee', term: 'coffee', meaning: 'cà phê'),
  PracticeWord(id: 'tea', term: 'tea', meaning: 'trà'),
  PracticeWord(id: 'egg', term: 'egg', meaning: 'quả trứng'),
  PracticeWord(id: 'chicken', term: 'chicken', meaning: 'thịt gà'),
  PracticeWord(id: 'soup', term: 'soup', meaning: 'món súp'),
  PracticeWord(id: 'noodles', term: 'noodles', meaning: 'mì'),
  PracticeWord(id: 'breakfast', term: 'breakfast', meaning: 'bữa sáng'),
  PracticeWord(id: 'lunch', term: 'lunch', meaning: 'bữa trưa'),
  PracticeWord(id: 'dinner', term: 'dinner', meaning: 'bữa tối'),
  PracticeWord(id: 'mother', term: 'mother', meaning: 'mẹ'),
  PracticeWord(id: 'father', term: 'father', meaning: 'bố'),
  PracticeWord(id: 'sister', term: 'sister', meaning: 'chị gái'),
  PracticeWord(id: 'brother', term: 'brother', meaning: 'anh trai'),
  PracticeWord(id: 'grandmother', term: 'grandmother', meaning: 'bà'),
  PracticeWord(id: 'grandfather', term: 'grandfather', meaning: 'ông'),
  PracticeWord(id: 'friend', term: 'friend', meaning: 'bạn bè'),
  PracticeWord(id: 'family', term: 'family', meaning: 'gia đình'),
  PracticeWord(id: 'teacher', term: 'teacher', meaning: 'giáo viên'),
  PracticeWord(id: 'student', term: 'student', meaning: 'học sinh'),
  PracticeWord(id: 'doctor', term: 'doctor', meaning: 'bác sĩ'),
  PracticeWord(id: 'nurse', term: 'nurse', meaning: 'y tá'),
  PracticeWord(id: 'engineer', term: 'engineer', meaning: 'kỹ sư'),
  PracticeWord(id: 'house', term: 'house', meaning: 'ngôi nhà'),
  PracticeWord(id: 'room', term: 'room', meaning: 'căn phòng'),
  PracticeWord(id: 'kitchen', term: 'kitchen', meaning: 'nhà bếp'),
  PracticeWord(id: 'bed', term: 'bed', meaning: 'cái giường'),
  PracticeWord(id: 'table', term: 'table', meaning: 'cái bàn'),
  PracticeWord(id: 'chair', term: 'chair', meaning: 'cái ghế'),
  PracticeWord(id: 'door', term: 'door', meaning: 'cửa ra vào'),
  PracticeWord(id: 'window', term: 'window', meaning: 'cửa sổ'),
  PracticeWord(id: 'book', term: 'book', meaning: 'quyển sách'),
  PracticeWord(id: 'pen', term: 'pen', meaning: 'cây bút'),
  PracticeWord(id: 'school', term: 'school', meaning: 'trường học'),
  PracticeWord(id: 'classroom', term: 'classroom', meaning: 'lớp học'),
  PracticeWord(id: 'homework', term: 'homework', meaning: 'bài tập về nhà'),
  PracticeWord(id: 'city', term: 'city', meaning: 'thành phố'),
  PracticeWord(id: 'street', term: 'street', meaning: 'đường phố'),
  PracticeWord(id: 'market', term: 'market', meaning: 'chợ'),
  PracticeWord(id: 'supermarket', term: 'supermarket', meaning: 'siêu thị'),
  PracticeWord(id: 'hospital', term: 'hospital', meaning: 'bệnh viện'),
  PracticeWord(id: 'airport', term: 'airport', meaning: 'sân bay'),
  PracticeWord(id: 'train', term: 'train', meaning: 'tàu hỏa'),
  PracticeWord(id: 'bus', term: 'bus', meaning: 'xe buýt'),
  PracticeWord(id: 'car', term: 'car', meaning: 'xe hơi'),
  PracticeWord(id: 'bicycle', term: 'bicycle', meaning: 'xe đạp'),
  PracticeWord(id: 'ticket', term: 'ticket', meaning: 'vé'),
  PracticeWord(id: 'hotel', term: 'hotel', meaning: 'khách sạn'),
  PracticeWord(id: 'money', term: 'money', meaning: 'tiền'),
  PracticeWord(id: 'expensive', term: 'expensive', meaning: 'đắt'),
  PracticeWord(id: 'cheap', term: 'cheap', meaning: 'rẻ'),
  PracticeWord(id: 'big', term: 'big', meaning: 'to'),
  PracticeWord(id: 'small', term: 'small', meaning: 'nhỏ'),
  PracticeWord(id: 'hot', term: 'hot', meaning: 'nóng'),
  PracticeWord(id: 'cold', term: 'cold', meaning: 'lạnh'),
  PracticeWord(id: 'happy', term: 'happy', meaning: 'vui vẻ'),
  PracticeWord(id: 'sad', term: 'sad', meaning: 'buồn'),
  PracticeWord(id: 'tired', term: 'tired', meaning: 'mệt'),
  PracticeWord(id: 'hungry', term: 'hungry', meaning: 'đói'),
  PracticeWord(id: 'thirsty', term: 'thirsty', meaning: 'khát'),
  PracticeWord(id: 'beautiful', term: 'beautiful', meaning: 'đẹp'),
  PracticeWord(id: 'today', term: 'today', meaning: 'hôm nay'),
  PracticeWord(id: 'tomorrow', term: 'tomorrow', meaning: 'ngày mai'),
  PracticeWord(id: 'yesterday', term: 'yesterday', meaning: 'hôm qua'),
  PracticeWord(id: 'morning', term: 'morning', meaning: 'buổi sáng'),
  PracticeWord(id: 'evening', term: 'evening', meaning: 'buổi tối'),
  PracticeWord(id: 'week', term: 'week', meaning: 'tuần'),
  PracticeWord(id: 'weekend', term: 'weekend', meaning: 'cuối tuần'),
  PracticeWord(id: 'rain', term: 'rain', meaning: 'mưa'),
  PracticeWord(id: 'sun', term: 'sun', meaning: 'mặt trời'),
  PracticeWord(id: 'weather', term: 'weather', meaning: 'thời tiết'),
  PracticeWord(id: 'music', term: 'music', meaning: 'âm nhạc'),
  PracticeWord(id: 'movie', term: 'movie', meaning: 'bộ phim'),
  PracticeWord(id: 'soccer', term: 'soccer', meaning: 'bóng đá'),
  PracticeWord(id: 'swim', term: 'swim', meaning: 'bơi'),
  PracticeWord(id: 'read', term: 'read', meaning: 'đọc'),
  PracticeWord(id: 'write', term: 'write', meaning: 'viết'),
  PracticeWord(id: 'speak', term: 'speak', meaning: 'nói'),
  PracticeWord(id: 'listen', term: 'listen', meaning: 'nghe'),
  PracticeWord(id: 'eat', term: 'eat', meaning: 'ăn'),
  PracticeWord(id: 'drink', term: 'drink', meaning: 'uống'),
  PracticeWord(id: 'sleep', term: 'sleep', meaning: 'ngủ'),
  PracticeWord(id: 'work', term: 'work', meaning: 'làm việc'),
  PracticeWord(id: 'travel', term: 'travel', meaning: 'đi du lịch'),
];

/// Open review mistakes (exercise ids from the local course fixtures).
const mockPracticeMistakes = <PracticeMistake>[
  PracticeMistake(exerciseId: 'u1n1l1-e03', skillId: 'u1.vocab', count: 2),
  PracticeMistake(exerciseId: 'u1n1l2-e05', skillId: 'u1.grammar', count: 1),
  PracticeMistake(exerciseId: 'u1n2l1-e02', skillId: 'u1.vocab', count: 3),
  PracticeMistake(exerciseId: 'u1n2l2-e07', skillId: 'listening', count: 1),
  PracticeMistake(exerciseId: 'u1n3l1-e04', skillId: 'u1.grammar', count: 2),
  PracticeMistake(exerciseId: 'u2n1l1-e06', skillId: 'u2.vocab', count: 1),
  PracticeMistake(exerciseId: 'u2n1l2-e01', skillId: 'speaking', count: 1),
  PracticeMistake(exerciseId: 'u2n2l1-e08', skillId: 'u2.grammar', count: 2),
];

const mockCallOpening = <ConversationLine>[
  ConversationLine(speaker: 'Lily', text: 'Hello.'),
];
