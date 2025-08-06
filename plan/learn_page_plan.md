# Plan for the "Learn" Feature

This document outlines the database schema and UI/UX strategy for implementing the "Learn" feature in the Robin application.

## Phase 1: Database Schema

The following tables will be created to support the learning feature. The design uses `UUID` for primary keys, `TIMESTAMPTZ` for timestamps, and `ENUM` types for data integrity. Foreign keys are defined with `ON DELETE CASCADE` to ensure that when a parent record is deleted, its dependent records are also removed.

### 1. `courses` Table
Stores the master list of all available courses.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the course. |
| `name` | `TEXT` | **Unique.** The name of the course (e.g., "Python", "Flutter"). |
| `description`| `TEXT` | A brief summary of what the course covers. |
| `course_type`| `ENUM` | `'language'` or `'framework'`. |
| `cover_image_url`| `TEXT` | URL for a course branding image. |
| `estimated_time_hours`| `INT` | Estimated hours to complete the course. |
| `created_at` | `TIMESTAMPTZ`| Timestamp of when the course was created. |

### 2. `topics` Table
Stores the individual lessons or modules that make up a course curriculum.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the topic. |
| `course_id` | `UUID` | **Foreign Key** referencing `courses.id`. |
| `title` | `TEXT` | The title of the topic (e.g., "Variables and Data Types"). |
| `description`| `TEXT` | A short description of the topic's content. |
| `topic_order`| `INT` | The sequential order of the topic within the course (1, 2, 3...). |
| `topic_type` | `ENUM` | `'regular'` or `'project'`. |
| `estimated_time_minutes`| `INT` | Estimated minutes to complete the topic. |
| `created_at` | `TIMESTAMPTZ`| Timestamp of when the topic was created. |

### 3. `enrollments` Table
A linking table that tracks which users are enrolled in which courses.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the enrollment. |
| `user_id` | `UUID` | **Foreign Key** referencing `public.users.id`. |
| `course_id` | `UUID` | **Foreign Key** referencing `courses.id`. |
| `status` | `ENUM` | `'not_started'`, `'in_progress'`, `'completed'`. |
| `progress` | `INT` | Percentage of course completion (0-100). |
| `difficulty` | `ENUM` | `'beginner'`, `'intermediate'`, `'advanced'`. |
| `learning_style`| `ENUM` | `'visual'`, `'kinesthetic'`, `'auditory'`, `'reading/writing'`. |
| `enrolled_at`| `TIMESTAMPTZ`| Timestamp of when the user enrolled. |
| `updated_at` | `TIMESTAMPTZ`| Timestamp of the last progress update. |

### 4. `topic_notes` Table
Stores the AI-generated educational content for each topic, personalized for the user's enrollment.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the note. |
| `enrollment_id`| `UUID` | **Foreign Key** referencing `enrollments.id`. |
| `topic_id` | `UUID` | **Foreign Key** referencing `topics.id`. |
| `note_title` | `TEXT` | e.g., "Getting Started", "Putting It to Work", "Mastery & Beyond". |
| `note_content`| `TEXT` | The full, AI-generated content of the note. |
| `note_order` | `INT` | The order of the note within the topic (1, 2, 3). |
| `created_at` | `TIMESTAMPTZ`| Timestamp of when the note was generated. |

### 5. `topic_quizzes` and `quiz_questions` Tables
Stores quizzes for each topic and their associated questions.

**`topic_quizzes`**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the quiz. |
| `enrollment_id`| `UUID` | **Foreign Key** referencing `enrollments.id`. |
| `topic_id` | `UUID` | **Foreign Key** referencing `topics.id`. |
| `created_at` | `TIMESTAMPTZ`| Timestamp of when the quiz was generated. |

**`quiz_questions`**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the question. |
| `quiz_id` | `UUID` | **Foreign Key** referencing `topic_quizzes.id`. |
| `question_order`| `INT` | The order of the question within the quiz (1, 2, 3...). |
| `question_text`| `TEXT` | The text of the question. |
| `options` | `JSONB` | A JSON array of possible answers, e.g., `[{"option": "A", "text": "..."}, ...]`. |
| `correct_option`| `TEXT` | The key of the correct option (e.g., "A"). |
| `explanation` | `TEXT` | An explanation for why the answer is correct. |

### 6. `suggested_projects` Table
Stores project ideas related to a specific topic.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the project. |
| `topic_id` | `UUID` | **Foreign Key** referencing `topics.id`. |
| `title` | `TEXT` | The title of the suggested project. |
| `description`| `TEXT` | A detailed description of the project requirements. |
| `stack` | `TEXT[]` | An array of technologies to be used (e.g., `['Flutter', 'Supabase']`). |
| `estimated_time_hours`| `INT` | Estimated hours to complete the project. |

### 7. `topic_chats` and `chat_messages` Tables
Stores the conversation history for the AI assistant within a topic.

**`topic_chats`**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the chat session. |
| `enrollment_id`| `UUID` | **Foreign Key** referencing `enrollments.id`. |
| `topic_id` | `UUID` | **Foreign Key** referencing `topics.id`. |
| `title` | `TEXT` | A title for the chat session. |
| `created_at` | `TIMESTAMPTZ`| Timestamp of when the chat was started. |

**`chat_messages`**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | **Primary Key.** Unique identifier for the message. |
| `chat_id` | `UUID` | **Foreign Key** referencing `topic_chats.id`. |
| `sender` | `ENUM` | `'user'` or `'ai'`. |
| `content` | `TEXT` | The text content of the message. |
| `sent_at` | `TIMESTAMT` | Timestamp of when the message was sent. |

### 8. `topic_facts` Table
Stores AI-generated fun facts related to a specific topic.

| Column      | Type        | Description                                           |
| :---------- | :---------- | :---------------------------------------------------- |
| `id`        | `UUID`      | **Primary Key.** Unique identifier for the fact.      |
| `topic_id`  | `UUID`      | **Foreign Key** referencing `topics.id`.              |
| `fact_text` | `TEXT`      | The content of the fun fact.                          |
| `created_at`| `TIMESTAMPTZ`| Timestamp of when the fact was generated.             |

### 9. `topic_practice_problems` Table
Stores AI-generated coding exercises for a topic.

| Column                | Type        | Description                                                      |
| :-------------------- | :---------- | :--------------------------------------------------------------- |
| `id`                  | `UUID`      | **Primary Key.** Unique identifier for the practice problem.     |
| `topic_id`            | `UUID`      | **Foreign Key** referencing `topics.id`.                         |
| `title`               | `TEXT`      | The title of the practice problem.                               |
| `description`         | `TEXT`      | A detailed description of the coding task.                       |
| `starting_code`       | `TEXT`      | Boilerplate code provided to the user.                           |
| `solution`            | `TEXT`      | The correct and complete code solution.                          |
| `test_cases`          | `JSONB`     | An array of test cases, e.g., `[{"input": ..., "expected": ...}]` |
| `created_at`          | `TIMESTAMPTZ`| Timestamp of when the problem was generated.                     |

## Phase 2: Data Seeding

The SQL script will include `INSERT` statements to populate the `courses` table with an initial set of languages and frameworks to make the feature usable immediately.

## Phase 3: UI/UX Strategy

- **Adopt Material 3:** As requested, all new UI development for the "Learn" feature and subsequent features will use the **Material 3** design system (`material.dart`'s `useMaterial3: true` theme setting).
- **Benefits:** This provides access to modern, adaptive components, improved theming capabilities, and ensures the application has a contemporary look and feel that aligns with the latest Android and Flutter design standards.
- **Integration with Existing Style:** While using Material 3 components, we will continue to apply the aesthetic principles from `plan/app_design.md`, such as glassmorphism, gradients, and custom animations, to maintain a unique and consistent brand identity.

## Action Plan

The following SQL script will now be created to implement the database schema described above.
