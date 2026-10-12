// Mirror of the AI service's scripted scenario catalog
// (services/ai/src/domain/scenarios.ts, `SCENARIOS`). The server has no
// scenario-list endpoint: conversations, tutor turns and voice turns all key
// on these ids, and `POST /v1/conversations` answers NOT_FOUND for any other.
// `test/features/server_scenarios_test.dart` fails when this copy drifts.
//
// The app keeps its own library cards (art, topic, copy); [roleplayServerLinks]
// maps each card onto the server scenario that plays it in API mode.

/// One partner line of a server script and the model learner answer.
class ServerScenarioStep {
  const ServerScenarioStep({
    required this.partner,
    required this.expect,
    required this.hintVi,
  });

  /// What the partner says at this step.
  final String partner;

  /// Model learner answer (what the scripted speech recognizer "hears").
  final String expect;

  /// Vietnamese coaching hint; most read `Label: "English phrase"`.
  final String hintVi;
}

class ServerScenario {
  const ServerScenario({
    required this.id,
    required this.title,
    required this.level,
    required this.partnerName,
    required this.steps,
    required this.closing,
  });
  final String id, title, level, partnerName, closing;
  final List<ServerScenarioStep> steps;
}

const serverScenarios = <ServerScenario>[
  ServerScenario(
    id: "rp_cafe_order",
    title: "Ordering at a café",
    level: "A1",
    partnerName: "Mia",
    steps: [
      ServerScenarioStep(
        partner: "Hi! Welcome to Sunny Café. What would you like to drink?",
        expect: "I would like a coffee, please.",
        hintVi: "Gọi đồ uống: \"I would like a coffee, please.\"",
      ),
      ServerScenarioStep(
        partner: "Sure. Small or large?",
        expect: "A small one, please.",
        hintVi: "Chọn cỡ: \"A small one, please.\"",
      ),
      ServerScenarioStep(
        partner: "Do you want milk or sugar?",
        expect: "Milk, no sugar, thank you.",
        hintVi: "Trả lời: \"Milk, no sugar, thank you.\"",
      ),
      ServerScenarioStep(
        partner: "That is three dollars. Here or to go?",
        expect: "To go, please. Here you are.",
        hintVi: "Mang đi là \"to go\", dùng tại chỗ là \"for here\".",
      ),
    ],
    closing: "Here is your coffee. Have a nice day!",
  ),
  ServerScenario(
    id: "rp_meet_new_friend",
    title: "Meeting a new friend",
    level: "A1",
    partnerName: "Tom",
    steps: [
      ServerScenarioStep(
        partner: "Hello! I am Tom. What is your name?",
        expect: "Hi Tom, my name is Lan.",
        hintVi: "Giới thiệu tên: \"My name is ...\"",
      ),
      ServerScenarioStep(
        partner: "Nice to meet you! Where are you from?",
        expect: "Nice to meet you too. I am from Vietnam.",
        hintVi: "Nói quê quán: \"I am from Vietnam.\"",
      ),
      ServerScenarioStep(
        partner: "Cool! What do you do?",
        expect: "I am a student.",
        hintVi: "Nói nghề nghiệp: \"I am a student.\"",
      ),
      ServerScenarioStep(
        partner: "What do you like to do on weekends?",
        expect: "I like reading books and playing football.",
        hintVi: "Sở thích: \"I like + V-ing.\"",
      ),
    ],
    closing: "That sounds fun. See you around!",
  ),
  ServerScenario(
    id: "rp_ask_directions",
    title: "Asking for directions",
    level: "A1",
    partnerName: "Ben",
    steps: [
      ServerScenarioStep(
        partner: "Hi, can I help you?",
        expect: "Excuse me, where is the train station?",
        hintVi: "Hỏi đường: \"Excuse me, where is the train station?\"",
      ),
      ServerScenarioStep(
        partner: "Go straight and turn left at the bank. Is that clear?",
        expect: "Go straight and turn left. Is it far?",
        hintVi: "Hỏi xa không: \"Is it far?\"",
      ),
      ServerScenarioStep(
        partner: "No, it is about five minutes on foot.",
        expect: "Great, five minutes. Can I walk there?",
        hintVi: "\"on foot\" nghĩa là đi bộ.",
      ),
      ServerScenarioStep(
        partner: "Yes, you can walk. It is next to a big park.",
        expect: "Thank you so much for your help!",
        hintVi: "Cảm ơn: \"Thank you so much for your help!\"",
      ),
    ],
    closing: "You are welcome. Have a good trip!",
  ),
  ServerScenario(
    id: "rp_shopping_clothes",
    title: "Buying a T-shirt",
    level: "A1",
    partnerName: "Anna",
    steps: [
      ServerScenarioStep(
        partner: "Good morning! Are you looking for something?",
        expect: "Yes, I am looking for a T-shirt.",
        hintVi: "Tìm mua: \"I am looking for a T-shirt.\"",
      ),
      ServerScenarioStep(
        partner: "What size and color do you want?",
        expect: "Medium, in blue, please.",
        hintVi: "Nói cỡ và màu: \"Medium, in blue.\"",
      ),
      ServerScenarioStep(
        partner: "Here you are. Do you want to try it on?",
        expect: "Yes, please. Where is the fitting room?",
        hintVi: "\"try it on\" là mặc thử.",
      ),
      ServerScenarioStep(
        partner: "It looks great on you! It is fifteen dollars.",
        expect: "How much? Fifteen dollars. OK, I will take it.",
        hintVi: "Quyết định mua: \"I will take it.\"",
      ),
    ],
    closing: "Thank you! Please pay at the counter.",
  ),
  ServerScenario(
    id: "rp_doctor_visit",
    title: "At the doctor",
    level: "A2",
    partnerName: "Dr. Smith",
    steps: [
      ServerScenarioStep(
        partner: "Hello, please sit down. What is the problem today?",
        expect: "I feel sick. I have a headache and a fever.",
        hintVi: "Mô tả triệu chứng: \"I have a headache and a fever.\"",
      ),
      ServerScenarioStep(
        partner: "I see. How long have you felt like this?",
        expect: "Since Monday, about three days.",
        hintVi: "Thời gian: \"Since Monday\" hoặc \"for three days\".",
      ),
      ServerScenarioStep(
        partner: "Are you taking any medicine now?",
        expect: "No, I am not taking any medicine.",
        hintVi: "Trả lời phủ định: \"No, I am not taking any medicine.\"",
      ),
      ServerScenarioStep(
        partner: "Take this medicine twice a day and get some rest.",
        expect: "Twice a day. I will rest. Thank you, doctor.",
        hintVi: "\"twice a day\" là hai lần mỗi ngày.",
      ),
    ],
    closing: "Drink a lot of water. I hope you feel better soon.",
  ),
  ServerScenario(
    id: "rp_hotel_check_in",
    title: "Checking in at a hotel",
    level: "A2",
    partnerName: "Lucy",
    steps: [
      ServerScenarioStep(
        partner: "Good evening. Welcome to the Riverside Hotel. Do you have a reservation?",
        expect: "Yes, I have a reservation under the name Nguyen.",
        hintVi: "Đặt phòng: \"I have a reservation under the name ...\"",
      ),
      ServerScenarioStep(
        partner: "Thank you. How many nights are you staying?",
        expect: "Two nights, please.",
        hintVi: "Số đêm: \"Two nights.\"",
      ),
      ServerScenarioStep(
        partner: "Can I see your passport, please?",
        expect: "Sure, here is my passport.",
        hintVi: "Đưa giấy tờ: \"Here is my passport.\"",
      ),
      ServerScenarioStep(
        partner:
            "Your room is on the fifth floor. Breakfast is from seven to ten.",
        expect: "Thank you. What is the wifi password?",
        hintVi: "Hỏi wifi: \"What is the wifi password?\"",
      ),
    ],
    closing: "The password is on your key card. Enjoy your stay!",
  ),
  ServerScenario(
    id: "rp_restaurant_dinner",
    title: "Dinner at a restaurant",
    level: "A2",
    partnerName: "Leo",
    steps: [
      ServerScenarioStep(
        partner: "Good evening! A table for how many people?",
        expect: "A table for two, please.",
        hintVi: "Đặt bàn: \"A table for two, please.\"",
      ),
      ServerScenarioStep(
        partner: "Here is the menu. Are you ready to order?",
        expect: "Yes. What do you recommend?",
        hintVi: "Hỏi gợi ý: \"What do you recommend?\"",
      ),
      ServerScenarioStep(
        partner: "The grilled chicken is very popular. Anything to drink?",
        expect: "I will have the chicken and a glass of water.",
        hintVi: "Gọi món: \"I will have the chicken.\"",
      ),
      ServerScenarioStep(
        partner: "How was your meal?",
        expect: "It was delicious. Can I have the bill, please?",
        hintVi: "Xin hóa đơn: \"Can I have the bill, please?\"",
      ),
    ],
    closing: "Here is your bill. Thank you for coming!",
  ),
  ServerScenario(
    id: "rp_bus_ticket",
    title: "Buying a bus ticket",
    level: "A1",
    partnerName: "Sam",
    steps: [
      ServerScenarioStep(
        partner: "Hello. Where are you going today?",
        expect: "I want a ticket to Da Lat, please.",
        hintVi: "Mua vé: \"I want a ticket to ...\"",
      ),
      ServerScenarioStep(
        partner: "One-way or return?",
        expect: "One-way, please. How much is it?",
        hintVi: "Vé một chiều \"one-way\", khứ hồi \"return\".",
      ),
      ServerScenarioStep(
        partner: "It is twelve dollars. The next bus leaves at nine thirty.",
        expect: "Nine thirty is good. Which platform?",
        hintVi: "Hỏi bến: \"Which platform?\"",
      ),
      ServerScenarioStep(
        partner: "Platform four. Here is your ticket.",
        expect: "Platform four. Thank you very much.",
        hintVi: "Nhắc lại thông tin để kiểm tra là thói quen tốt.",
      ),
    ],
    closing: "Have a safe trip!",
  ),
  ServerScenario(
    id: "rp_weekend_plans",
    title: "Making weekend plans",
    level: "A2",
    partnerName: "Emma",
    steps: [
      ServerScenarioStep(
        partner: "Hey! Are you free this Saturday?",
        expect: "Yes, I am free on Saturday. Why?",
        hintVi: "Rảnh không: \"I am free on Saturday.\"",
      ),
      ServerScenarioStep(
        partner: "Do you want to see a movie with me?",
        expect: "That is a great idea! Which movie?",
        hintVi: "Đồng ý: \"That is a great idea!\"",
      ),
      ServerScenarioStep(
        partner: "A new comedy. What time is good for you?",
        expect: "Seven o’clock in the evening is good for me.",
        hintVi: "Hẹn giờ: \"Seven o’clock is good for me.\"",
      ),
      ServerScenarioStep(
        partner: "Perfect. Where should we meet?",
        expect: "Let’s meet in front of the cinema.",
        hintVi: "Rủ rê: \"Let’s meet ...\"",
      ),
    ],
    closing: "See you on Saturday at seven!",
  ),
  ServerScenario(
    id: "rp_job_interview",
    title: "A simple job interview",
    level: "A2",
    partnerName: "Mr. Brown",
    steps: [
      ServerScenarioStep(
        partner: "Thank you for coming. Can you tell me about yourself?",
        expect: "My name is Minh. I am twenty-two and I studied business.",
        hintVi: "Giới thiệu bản thân ngắn gọn: tên, tuổi, ngành học.",
      ),
      ServerScenarioStep(
        partner: "Do you have any work experience?",
        expect: "Yes, I worked in a shop for one year.",
        hintVi: "Kinh nghiệm: \"I worked in a shop for one year.\"",
      ),
      ServerScenarioStep(
        partner: "Why do you want this job?",
        expect: "Because I like working in a team and I want to learn.",
        hintVi: "Giải thích lý do với \"because\".",
      ),
      ServerScenarioStep(
        partner: "Can you work on weekends?",
        expect: "Yes, I can work on weekends.",
        hintVi: "Trả lời khả năng: \"Yes, I can ...\"",
      ),
    ],
    closing: "Thank you. We will call you next week.",
  ),
  ServerScenario(
    id: "rp_phone_pizza",
    title: "Ordering pizza by phone",
    level: "A1",
    partnerName: "Pizza Palace",
    steps: [
      ServerScenarioStep(
        partner: "Pizza Palace, how can I help you?",
        expect: "Hi, I want to order a pizza for delivery.",
        hintVi: "Gọi giao hàng: \"I want to order a pizza for delivery.\"",
      ),
      ServerScenarioStep(
        partner: "What kind of pizza would you like?",
        expect: "A large cheese pizza, please.",
        hintVi: "Chọn loại: \"A large cheese pizza, please.\"",
      ),
      ServerScenarioStep(
        partner: "What is your address?",
        expect: "My address is 25 Le Loi Street.",
        hintVi: "Địa chỉ: \"My address is ...\"",
      ),
      ServerScenarioStep(
        partner: "It will be there in thirty minutes. Cash or card?",
        expect: "Cash, please. Thank you.",
        hintVi: "Thanh toán: \"Cash, please\" hoặc \"By card\".",
      ),
    ],
    closing: "Thank you for your order. Enjoy your pizza!",
  ),
  ServerScenario(
    id: "rp_daily_routine",
    title: "Talking about your day",
    level: "A1",
    partnerName: "Lily",
    steps: [
      ServerScenarioStep(
        partner: "Hi! What time do you usually get up?",
        expect: "I usually get up at six o’clock.",
        hintVi: "Thói quen: \"I usually get up at ...\"",
      ),
      ServerScenarioStep(
        partner: "What do you have for breakfast?",
        expect: "I have bread and milk for breakfast.",
        hintVi: "Bữa sáng: \"I have ... for breakfast.\"",
      ),
      ServerScenarioStep(
        partner: "How do you go to school or work?",
        expect: "I go to school by motorbike.",
        hintVi: "Phương tiện: \"by bus\", \"by motorbike\".",
      ),
      ServerScenarioStep(
        partner: "What do you do in the evening?",
        expect: "I study English and then I go to bed at ten.",
        hintVi: "Buổi tối: \"I study English and then I go to bed.\"",
      ),
    ],
    closing: "You have a busy day. Great job talking about it!",
  ),
];

ServerScenario? serverScenarioById(String id) {
  for (final s in serverScenarios) {
    if (s.id == id) return s;
  }
  return null;
}

/// How a bundled library card plays against the server.
class RoleplayServerLink {
  const RoleplayServerLink(this.serverId, {this.retitle = false});

  /// Server scenario id the card's conversation runs on.
  final String serverId;

  /// The card's bundled title/setting describe a different situation than the
  /// server script (e.g. fruit market vs. T-shirt shop): in API mode the card
  /// takes the server title so what the learner reads matches what is said.
  final bool retitle;
}

/// Bundled library card id -> server scenario. Cards without an entry (none
/// today) fall back to [fallbackServerScenarioId].
const roleplayServerLinks = <String, RoleplayServerLink>{
  'restaurant': RoleplayServerLink('rp_restaurant_dinner'),
  'market': RoleplayServerLink('rp_shopping_clothes', retitle: true),
  'airport': RoleplayServerLink('rp_bus_ticket'),
  'hotel': RoleplayServerLink('rp_hotel_check_in'),
  'morning': RoleplayServerLink('rp_daily_routine'),
  'movie': RoleplayServerLink('rp_weekend_plans'),
  'interview': RoleplayServerLink('rp_job_interview'),
  'directions': RoleplayServerLink('rp_ask_directions'),
  'party': RoleplayServerLink('rp_phone_pizza', retitle: true),
  'intro': RoleplayServerLink('rp_meet_new_friend'),
  'neighbor': RoleplayServerLink('rp_meet_new_friend'),
};

/// Used for a card id the table does not know.
const fallbackServerScenarioId = 'rp_cafe_order';

/// Server scenario for a card id (a server id passes through unchanged).
String serverScenarioIdFor(String cardId) {
  final link = roleplayServerLinks[cardId];
  if (link != null) return link.serverId;
  if (serverScenarioById(cardId) != null) return cardId;
  return fallbackServerScenarioId;
}

/// Library card that shows server history for [serverId]: the first card
/// linked to it (so `intro`, not `neighbor`, owns rp_meet_new_friend), else
/// null for server scenarios no card plays.
String? cardIdForServerScenario(String serverId) {
  for (final e in roleplayServerLinks.entries) {
    if (e.value.serverId == serverId) return e.key;
  }
  return null;
}

/// Video-call partner id -> server scenario (Lily's daily-routine script).
const callServerLinks = <String, String>{'lily': 'rp_daily_routine'};

String callServerScenarioIdFor(String partnerId) =>
    callServerLinks[partnerId] ??
    (serverScenarioById(partnerId) != null
        ? partnerId
        : callServerLinks['lily']!);
