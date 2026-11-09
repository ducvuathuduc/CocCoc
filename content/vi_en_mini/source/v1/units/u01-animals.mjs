// Unit 1 — Animals (A1). The second course's only unit: one section, one unit, 24 sentences, so a
// test can build a whole independent course in memory. Format: see tools/content/course-lib.mjs.
export default {
  theme: 'animals',
  cefr: 'A1',
  title: 'Động vật quanh em',
  levels: ['Con vật quen thuộc', 'Chúng làm gì?', 'To hay nhỏ?', 'Ăn và uống', 'Cảm xúc'],
  guide: `
Mẫu câu chính: "The dog can run." (Con chó có thể chạy.) — "The cat is small." (Con mèo thì nhỏ.)
Ngữ pháp: "can" + động từ nguyên mẫu để nói khả năng; động từ "to be" (is) để miêu tả.
Mẹo: tiếng Anh luôn có mạo từ trước con vật: "the dog", "a cat". Tiếng Việt thường bỏ "một".
`,
  vocab: `
1 dog | con chó | img
1 cat | con mèo | img
1 bird | con chim | img
1 fish | con cá | img
2 run | chạy
2 jump | nhảy
2 swim | bơi
2 fly | bay
3 big | to / lớn
3 small | nhỏ / bé
3 fast | nhanh
3 slow | chậm
4 eat | ăn
4 drink | uống
5 happy | vui / hạnh phúc
5 hungry | đói
`,
  sentences: `
I see a dog. = Tôi thấy một con chó.
I see a cat. = Tôi thấy một con mèo.
I see a bird. = Tôi thấy một con chim.
I see a fish. = Tôi thấy một con cá.
The dog and the cat. = Con chó và con mèo.
The dog can run. = Con chó có thể chạy.
The cat can jump. = Con mèo có thể nhảy.
The bird can fly. = Con chim có thể bay.
The fish can swim. = Con cá có thể bơi.
The dog can run and jump. = Con chó có thể chạy và nhảy.
The dog is big. = Con chó thì to.
The cat is small. = Con mèo thì nhỏ.
The bird is fast. = Con chim thì nhanh.
The fish is slow. = Con cá thì chậm.
A big dog can run fast. = Một con chó to có thể chạy nhanh.
The dog can eat. = Con chó có thể ăn.
The cat can drink. = Con mèo có thể uống.
The big dog can eat and drink. = Con chó to có thể ăn và uống.
The small cat can drink. = Con mèo nhỏ có thể uống.
My dog can eat fast. = Con chó của tôi có thể ăn nhanh.
The dog is happy. = Con chó thì vui.
The cat is hungry. = Con mèo thì đói.
The happy dog can run. = Con chó vui có thể chạy.
The hungry cat can eat. = Con mèo đói có thể ăn.
`,
  dialogues: `
Hello, dog! => Hello! = Xin chào!
Can the cat jump? => Yes, it can. = Vâng, nó có thể.
Is the bird fast? => Yes, it is fast. = Vâng, nó nhanh.
Can the dog eat? => Yes, the dog can eat. = Vâng, con chó có thể ăn.
Is the cat hungry? => Yes, the cat is hungry. = Vâng, con mèo đói.
Is the dog happy? => Yes, the dog is happy. = Vâng, con chó vui.
The fish can swim. => Yes, it can swim. = Vâng, nó có thể bơi.
`,
  story: {
    title: 'Con chó và con mèo',
    passage: `Mai has a dog and a cat. The dog is big and happy. The cat is small and hungry.
The bird can fly. The fish can swim. The dog can run and jump. The cat can jump too.
Mai says, "The dog is fast and the cat is slow." Then she gives them food.`,
    questions: `
Who can run? * The dog | The fish | The bird
Who can swim? * The fish | The cat | The bird
Who is big? * The dog | The cat | The fish
What can the cat do? * Jump | Fly | Swim
Who is hungry? * The cat | The dog | The bird
Who is happy? * The dog | The fish | The cat
`,
  },
};
