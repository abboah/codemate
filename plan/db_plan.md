# Latest Database Schema for Robin



This document outlines the redesigned database structure for **Robin**, now leveraging **Supabase with PostgreSQL** instead of Firebase. This schema supports agentic interactions, lesson generation, quizzes, feedback mechanisms, and multi-turn chat storage.

---

- [x]  🧑‍💻 Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  avatar_url TEXT NULL,  
  created_at TIMESTAMP DEFAULT NOW(),
  has_completed_onboarding BOOLEAN DEFAULT FALSE
);

```

---

- [x]  📂 Projects Table

```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

---

- [x]  📚 Courses Table

```sql
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

- [x]  👥 Enrollments Table (Many-to-Many: Users <> Courses)

```sql
CREATE TABLE enrollments (
  user_id UUID REFERENCES users(id),
  course_id UUID REFERENCES courses(id),
  enrolled_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, course_id)
);

```

---

- [x]  📝 Lessons Table (Per Course)

```sql
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id),
  title TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

---

- [ ]  🧠 Suggested Projects Table

```sql
CREATE TABLE suggested_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id),
  title TEXT NOT NULL,
  description TEXT,
  difficulty_level TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

---

- [ ]  ❓ Quizzes Table

```sql
CREATE TABLE quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id),
  title TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

- [ ]  🧾 Quiz Questions Table

```sql
CREATE TABLE quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID REFERENCES quizzes(id),
  question TEXT,
  options JSONB,
  correct_answer TEXT
);

```

---

- [x]  🤖 Agent Chats Table

```sql
CREATE TABLE agent_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

```

- [x]  💬 Messages Table

```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID REFERENCES agent_chats(id),
  sender TEXT CHECK (sender IN ('user', 'agent')),
  content TEXT,
  message_type TEXT, -- 'text', 'code', 'tool_use', etc.
  created_at TIMESTAMP DEFAULT NOW()
);

```

---

- [x]  🔁 Feedback Table (Unified for Chats, Quizzes, Lessons, etc.)

```sql
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  target_type TEXT, -- 'lesson', 'quiz', 'chat_message'
  target_id UUID,
  action TEXT CHECK (action IN ('like', 'dislike', 'copy', 'regenerate')),
  feedback_strength TEXT CHECK (
    feedback_strength IN ('positive', 'inferred_positive', 'neutral', 'weak_negative', 'negative')
  ),
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

```

---

## ✅ Summary of Relationships

- One user can have many projects, chats, feedback, and course enrollments.
- Each course has lessons, quizzes, and suggested projects.
- Each quiz has multiple questions.
- Chats contain multiple multi-turn messages.

---

Let me know if you’d like ER diagrams or Supabase SQL migrations next!