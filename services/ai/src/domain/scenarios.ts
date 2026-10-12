// Scripted roleplay scenarios for the deterministic provider (COC_AI_PROVIDER=disabled, no model).
// Authored A1-A2 English for Vietnamese learners: each step is one partner line, the model learner
// answer the scripted speech turn "hears", the keywords that count a free-text answer as on-topic,
// and a short Vietnamese hint used as the tutor explanation (feedbackLocale vi-VN).
// The same script serves ROLEPLAY and VIDEO_CALL (Video Call is an audio conversation with an
// avatar; no camera). Pure data + pure functions: no I/O, no randomness.

export type Level = 'A1' | 'A2';

export interface ScenarioStep {
  partner: string;
  expect: string;
  keywords: readonly string[];
  hintVi: string;
}

export interface Scenario {
  id: string;
  title: string;
  level: Level;
  partnerName: string;
  /** Words the learner is encouraged to use; wordsUsed counts the distinct ones actually used. */
  targetWords: readonly string[];
  steps: readonly ScenarioStep[];
  closing: string;
}

export const SCENARIOS: readonly Scenario[] = [
  {
    id: 'rp_cafe_order',
    title: 'Ordering at a café',
    level: 'A1',
    partnerName: 'Mia',
    targetWords: ['coffee', 'tea', 'please', 'small', 'large', 'milk', 'sugar', 'thank'],
    steps: [
      {
        partner: 'Hi! Welcome to Sunny Café. What would you like to drink?',
        expect: 'I would like a coffee, please.',
        keywords: ['coffee', 'tea', 'juice', 'water', 'like', 'please'],
        hintVi: 'Gọi đồ uống: "I would like a coffee, please."',
      },
      {
        partner: 'Sure. Small or large?',
        expect: 'A small one, please.',
        keywords: ['small', 'large', 'medium'],
        hintVi: 'Chọn cỡ: "A small one, please."',
      },
      {
        partner: 'Do you want milk or sugar?',
        expect: 'Milk, no sugar, thank you.',
        keywords: ['milk', 'sugar', 'no', 'yes'],
        hintVi: 'Trả lời: "Milk, no sugar, thank you."',
      },
      {
        partner: 'That is three dollars. Here or to go?',
        expect: 'To go, please. Here you are.',
        keywords: ['here', 'go', 'please', 'you are'],
        hintVi: 'Mang đi là "to go", dùng tại chỗ là "for here".',
      },
    ],
    closing: 'Here is your coffee. Have a nice day!',
  },
  {
    id: 'rp_meet_new_friend',
    title: 'Meeting a new friend',
    level: 'A1',
    partnerName: 'Tom',
    targetWords: ['name', 'from', 'Vietnam', 'nice', 'meet', 'student', 'like', 'years'],
    steps: [
      {
        partner: 'Hello! I am Tom. What is your name?',
        expect: 'Hi Tom, my name is Lan.',
        keywords: ['name', 'i am', "i'm", 'my'],
        hintVi: 'Giới thiệu tên: "My name is ..."',
      },
      {
        partner: 'Nice to meet you! Where are you from?',
        expect: 'Nice to meet you too. I am from Vietnam.',
        keywords: ['from', 'vietnam', 'live'],
        hintVi: 'Nói quê quán: "I am from Vietnam."',
      },
      {
        partner: 'Cool! What do you do?',
        expect: 'I am a student.',
        keywords: ['student', 'work', 'teacher', 'job', 'am a'],
        hintVi: 'Nói nghề nghiệp: "I am a student."',
      },
      {
        partner: 'What do you like to do on weekends?',
        expect: 'I like reading books and playing football.',
        keywords: ['like', 'love', 'play', 'read', 'watch'],
        hintVi: 'Sở thích: "I like + V-ing."',
      },
    ],
    closing: 'That sounds fun. See you around!',
  },
  {
    id: 'rp_ask_directions',
    title: 'Asking for directions',
    level: 'A1',
    partnerName: 'Ben',
    targetWords: ['where', 'station', 'left', 'right', 'straight', 'far', 'thanks', 'excuse'],
    steps: [
      {
        partner: 'Hi, can I help you?',
        expect: 'Excuse me, where is the train station?',
        keywords: ['where', 'station', 'excuse', 'how'],
        hintVi: 'Hỏi đường: "Excuse me, where is the train station?"',
      },
      {
        partner: 'Go straight and turn left at the bank. Is that clear?',
        expect: 'Go straight and turn left. Is it far?',
        keywords: ['straight', 'left', 'far', 'yes'],
        hintVi: 'Hỏi xa không: "Is it far?"',
      },
      {
        partner: 'No, it is about five minutes on foot.',
        expect: 'Great, five minutes. Can I walk there?',
        keywords: ['walk', 'minutes', 'great', 'ok'],
        hintVi: '"on foot" nghĩa là đi bộ.',
      },
      {
        partner: 'Yes, you can walk. It is next to a big park.',
        expect: 'Thank you so much for your help!',
        keywords: ['thank', 'thanks'],
        hintVi: 'Cảm ơn: "Thank you so much for your help!"',
      },
    ],
    closing: 'You are welcome. Have a good trip!',
  },
  {
    id: 'rp_shopping_clothes',
    title: 'Buying a T-shirt',
    level: 'A1',
    partnerName: 'Anna',
    targetWords: ['shirt', 'size', 'blue', 'try', 'how much', 'expensive', 'take', 'medium'],
    steps: [
      {
        partner: 'Good morning! Are you looking for something?',
        expect: 'Yes, I am looking for a T-shirt.',
        keywords: ['shirt', 't-shirt', 'looking', 'yes'],
        hintVi: 'Tìm mua: "I am looking for a T-shirt."',
      },
      {
        partner: 'What size and color do you want?',
        expect: 'Medium, in blue, please.',
        keywords: ['size', 'medium', 'small', 'large', 'blue', 'red', 'black', 'white'],
        hintVi: 'Nói cỡ và màu: "Medium, in blue."',
      },
      {
        partner: 'Here you are. Do you want to try it on?',
        expect: 'Yes, please. Where is the fitting room?',
        keywords: ['try', 'yes', 'fitting', 'room'],
        hintVi: '"try it on" là mặc thử.',
      },
      {
        partner: 'It looks great on you! It is fifteen dollars.',
        expect: 'How much? Fifteen dollars. OK, I will take it.',
        keywords: ['take', 'how much', 'ok', 'buy'],
        hintVi: 'Quyết định mua: "I will take it."',
      },
    ],
    closing: 'Thank you! Please pay at the counter.',
  },
  {
    id: 'rp_doctor_visit',
    title: 'At the doctor',
    level: 'A2',
    partnerName: 'Dr. Smith',
    targetWords: ['headache', 'fever', 'since', 'medicine', 'rest', 'days', 'feel', 'sick'],
    steps: [
      {
        partner: 'Hello, please sit down. What is the problem today?',
        expect: 'I feel sick. I have a headache and a fever.',
        keywords: ['sick', 'headache', 'fever', 'pain', 'hurt', 'feel'],
        hintVi: 'Mô tả triệu chứng: "I have a headache and a fever."',
      },
      {
        partner: 'I see. How long have you felt like this?',
        expect: 'Since Monday, about three days.',
        keywords: ['since', 'days', 'yesterday', 'week', 'monday'],
        hintVi: 'Thời gian: "Since Monday" hoặc "for three days".',
      },
      {
        partner: 'Are you taking any medicine now?',
        expect: 'No, I am not taking any medicine.',
        keywords: ['medicine', 'no', 'yes', 'taking', 'pills'],
        hintVi: 'Trả lời phủ định: "No, I am not taking any medicine."',
      },
      {
        partner: 'Take this medicine twice a day and get some rest.',
        expect: 'Twice a day. I will rest. Thank you, doctor.',
        keywords: ['rest', 'thank', 'twice', 'ok'],
        hintVi: '"twice a day" là hai lần mỗi ngày.',
      },
    ],
    closing: 'Drink a lot of water. I hope you feel better soon.',
  },
  {
    id: 'rp_hotel_check_in',
    title: 'Checking in at a hotel',
    level: 'A2',
    partnerName: 'Lucy',
    targetWords: ['reservation', 'nights', 'passport', 'breakfast', 'room', 'key', 'floor', 'wifi'],
    steps: [
      {
        partner: 'Good evening. Welcome to the Riverside Hotel. Do you have a reservation?',
        expect: 'Yes, I have a reservation under the name Nguyen.',
        keywords: ['reservation', 'booking', 'name', 'yes'],
        hintVi: 'Đặt phòng: "I have a reservation under the name ..."',
      },
      {
        partner: 'Thank you. How many nights are you staying?',
        expect: 'Two nights, please.',
        keywords: ['nights', 'night', 'two', 'three', 'one'],
        hintVi: 'Số đêm: "Two nights."',
      },
      {
        partner: 'Can I see your passport, please?',
        expect: 'Sure, here is my passport.',
        keywords: ['passport', 'here', 'sure', 'id'],
        hintVi: 'Đưa giấy tờ: "Here is my passport."',
      },
      {
        partner: 'Your room is on the fifth floor. Breakfast is from seven to ten.',
        expect: 'Thank you. What is the wifi password?',
        keywords: ['wifi', 'password', 'thank', 'breakfast', 'key'],
        hintVi: 'Hỏi wifi: "What is the wifi password?"',
      },
    ],
    closing: 'The password is on your key card. Enjoy your stay!',
  },
  {
    id: 'rp_restaurant_dinner',
    title: 'Dinner at a restaurant',
    level: 'A2',
    partnerName: 'Leo',
    targetWords: ['table', 'menu', 'chicken', 'water', 'bill', 'delicious', 'order', 'recommend'],
    steps: [
      {
        partner: 'Good evening! A table for how many people?',
        expect: 'A table for two, please.',
        keywords: ['table', 'two', 'one', 'three', 'four', 'people'],
        hintVi: 'Đặt bàn: "A table for two, please."',
      },
      {
        partner: 'Here is the menu. Are you ready to order?',
        expect: 'Yes. What do you recommend?',
        keywords: ['recommend', 'ready', 'yes', 'order', 'menu'],
        hintVi: 'Hỏi gợi ý: "What do you recommend?"',
      },
      {
        partner: 'The grilled chicken is very popular. Anything to drink?',
        expect: 'I will have the chicken and a glass of water.',
        keywords: ['chicken', 'water', 'have', 'drink', 'juice'],
        hintVi: 'Gọi món: "I will have the chicken."',
      },
      {
        partner: 'How was your meal?',
        expect: 'It was delicious. Can I have the bill, please?',
        keywords: ['delicious', 'bill', 'check', 'good', 'great'],
        hintVi: 'Xin hóa đơn: "Can I have the bill, please?"',
      },
    ],
    closing: 'Here is your bill. Thank you for coming!',
  },
  {
    id: 'rp_bus_ticket',
    title: 'Buying a bus ticket',
    level: 'A1',
    partnerName: 'Sam',
    targetWords: ['ticket', 'one-way', 'return', 'when', 'leave', 'platform', 'how much', 'today'],
    steps: [
      {
        partner: 'Hello. Where are you going today?',
        expect: 'I want a ticket to Da Lat, please.',
        keywords: ['ticket', 'to', 'going', 'want'],
        hintVi: 'Mua vé: "I want a ticket to ..."',
      },
      {
        partner: 'One-way or return?',
        expect: 'One-way, please. How much is it?',
        keywords: ['one-way', 'one way', 'return', 'how much'],
        hintVi: 'Vé một chiều "one-way", khứ hồi "return".',
      },
      {
        partner: 'It is twelve dollars. The next bus leaves at nine thirty.',
        expect: 'Nine thirty is good. Which platform?',
        keywords: ['platform', 'good', 'when', 'leave', 'which'],
        hintVi: 'Hỏi bến: "Which platform?"',
      },
      {
        partner: 'Platform four. Here is your ticket.',
        expect: 'Platform four. Thank you very much.',
        keywords: ['thank', 'four', 'ok'],
        hintVi: 'Nhắc lại thông tin để kiểm tra là thói quen tốt.',
      },
    ],
    closing: 'Have a safe trip!',
  },
  {
    id: 'rp_weekend_plans',
    title: 'Making weekend plans',
    level: 'A2',
    partnerName: 'Emma',
    targetWords: ['Saturday', 'free', 'movie', 'meet', 'time', 'o\u2019clock', 'idea', 'cinema'],
    steps: [
      {
        partner: 'Hey! Are you free this Saturday?',
        expect: 'Yes, I am free on Saturday. Why?',
        keywords: ['free', 'saturday', 'yes', 'busy'],
        hintVi: 'Rảnh không: "I am free on Saturday."',
      },
      {
        partner: 'Do you want to see a movie with me?',
        expect: 'That is a great idea! Which movie?',
        keywords: ['idea', 'movie', 'great', 'sure', 'yes'],
        hintVi: 'Đồng ý: "That is a great idea!"',
      },
      {
        partner: 'A new comedy. What time is good for you?',
        expect: 'Seven o\u2019clock in the evening is good for me.',
        keywords: ['time', 'clock', 'evening', 'seven', 'pm', 'good'],
        hintVi: 'Hẹn giờ: "Seven o\u2019clock is good for me."',
      },
      {
        partner: 'Perfect. Where should we meet?',
        expect: 'Let\u2019s meet in front of the cinema.',
        keywords: ['meet', 'cinema', 'front', 'let'],
        hintVi: 'Rủ rê: "Let\u2019s meet ..."',
      },
    ],
    closing: 'See you on Saturday at seven!',
  },
  {
    id: 'rp_job_interview',
    title: 'A simple job interview',
    level: 'A2',
    partnerName: 'Mr. Brown',
    targetWords: ['experience', 'work', 'team', 'learn', 'strong', 'English', 'hours', 'because'],
    steps: [
      {
        partner: 'Thank you for coming. Can you tell me about yourself?',
        expect: 'My name is Minh. I am twenty-two and I studied business.',
        keywords: ['name', 'studied', 'am', 'years', 'student'],
        hintVi: 'Giới thiệu bản thân ngắn gọn: tên, tuổi, ngành học.',
      },
      {
        partner: 'Do you have any work experience?',
        expect: 'Yes, I worked in a shop for one year.',
        keywords: ['experience', 'worked', 'work', 'year', 'yes', 'no'],
        hintVi: 'Kinh nghiệm: "I worked in a shop for one year."',
      },
      {
        partner: 'Why do you want this job?',
        expect: 'Because I like working in a team and I want to learn.',
        keywords: ['because', 'team', 'learn', 'like', 'want'],
        hintVi: 'Giải thích lý do với "because".',
      },
      {
        partner: 'Can you work on weekends?',
        expect: 'Yes, I can work on weekends.',
        keywords: ['can', 'weekends', 'yes', 'hours'],
        hintVi: 'Trả lời khả năng: "Yes, I can ..."',
      },
    ],
    closing: 'Thank you. We will call you next week.',
  },
  {
    id: 'rp_phone_pizza',
    title: 'Ordering pizza by phone',
    level: 'A1',
    partnerName: 'Pizza Palace',
    targetWords: ['pizza', 'large', 'address', 'cheese', 'delivery', 'phone', 'minutes', 'cash'],
    steps: [
      {
        partner: 'Pizza Palace, how can I help you?',
        expect: 'Hi, I want to order a pizza for delivery.',
        keywords: ['pizza', 'order', 'delivery', 'want'],
        hintVi: 'Gọi giao hàng: "I want to order a pizza for delivery."',
      },
      {
        partner: 'What kind of pizza would you like?',
        expect: 'A large cheese pizza, please.',
        keywords: ['cheese', 'large', 'small', 'chicken', 'pizza'],
        hintVi: 'Chọn loại: "A large cheese pizza, please."',
      },
      {
        partner: 'What is your address?',
        expect: 'My address is 25 Le Loi Street.',
        keywords: ['address', 'street', 'road', 'number'],
        hintVi: 'Địa chỉ: "My address is ..."',
      },
      {
        partner: 'It will be there in thirty minutes. Cash or card?',
        expect: 'Cash, please. Thank you.',
        keywords: ['cash', 'card', 'thank'],
        hintVi: 'Thanh toán: "Cash, please" hoặc "By card".',
      },
    ],
    closing: 'Thank you for your order. Enjoy your pizza!',
  },
  {
    id: 'rp_daily_routine',
    title: 'Talking about your day',
    level: 'A1',
    partnerName: 'Lily',
    targetWords: ['get up', 'breakfast', 'school', 'work', 'usually', 'evening', 'bed', 'every'],
    steps: [
      {
        partner: 'Hi! What time do you usually get up?',
        expect: 'I usually get up at six o\u2019clock.',
        keywords: ['get up', 'wake', 'usually', 'clock', 'six', 'seven'],
        hintVi: 'Thói quen: "I usually get up at ..."',
      },
      {
        partner: 'What do you have for breakfast?',
        expect: 'I have bread and milk for breakfast.',
        keywords: ['breakfast', 'have', 'eat', 'bread', 'rice', 'pho'],
        hintVi: 'Bữa sáng: "I have ... for breakfast."',
      },
      {
        partner: 'How do you go to school or work?',
        expect: 'I go to school by motorbike.',
        keywords: ['school', 'work', 'by', 'bus', 'motorbike', 'walk', 'go'],
        hintVi: 'Phương tiện: "by bus", "by motorbike".',
      },
      {
        partner: 'What do you do in the evening?',
        expect: 'I study English and then I go to bed at ten.',
        keywords: ['evening', 'study', 'bed', 'watch', 'cook'],
        hintVi: 'Buổi tối: "I study English and then I go to bed."',
      },
    ],
    closing: 'You have a busy day. Great job talking about it!',
  },
];

const BY_ID = new Map(SCENARIOS.map((s) => [s.id, s]));

export function scenarioById(id: string): Scenario | undefined {
  return BY_ID.get(id);
}

/** Lowercased word-ish normalization used for keyword and target-word matching. */
export function normalize(text: string): string {
  return ` ${text
    .toLowerCase()
    .replace(/[\u2019']/g, '\u2019')
    .replace(/[^a-z0-9\u2019\- ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()} `;
}

function contains(haystack: string, phrase: string): boolean {
  return haystack.includes(` ${normalize(phrase).trim()} `);
}

/** True when the learner text uses at least one of the step's keywords. */
export function onTopic(step: ScenarioStep, learnerText: string): boolean {
  const text = normalize(learnerText);
  return step.keywords.some((k) => contains(text, k));
}

/** Distinct target words of the scenario used in the learner text (canonical spelling). */
export function usedTargetWords(scenario: Scenario, learnerText: string): string[] {
  const text = normalize(learnerText);
  return scenario.targetWords.filter((w) => contains(text, w));
}

export function countWords(text: string): number {
  return normalize(text).trim().split(' ').filter(Boolean).length;
}
