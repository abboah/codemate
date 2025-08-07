# Build Section Revamp Plan

## 1. Vision & Core Principles

The "Build" section will be transformed from a simple toggle view into a powerful, integrated development environment (IDE) experience, reminiscent of VS Code. The core goal is to provide a seamless interface where users can chat with an AI agent, see the agent's actions reflected in real-time in a code editor, and manage their project's file structure.

- **Principle 1: Unified Experience:** Chat, code, and terminal are not separate modes but integrated panes in a single view.
- **Principle 2: Agent-Driven Development:** The AI agent is a core part of the workflow, capable of performing file operations, running commands, and assisting with code.
- **Principle 3: User Control & Visibility:** The user has full control, with a clear view of the file structure, editor tabs, and an interactive terminal. Checkpointing provides a safety net for experimentation.
- **Principle 4: Modern UI:** The interface will be clean, responsive, and adhere to Material 3 design principles.

## 2. UI/UX Design: The "VS Code" Layout

The main screen will be a multi-pane layout.

- **Left Pane (Resizable, initially 75%): The Editor & File Tree**
    - **File Tree Sidebar:** A collapsible sidebar on the far left, expanding on hover or click, displaying the project's file and folder structure.
    - **Editor View:** The main area of the left pane will be powered by the **Monaco Editor**. It will support multiple tabs for open files.
- **Right Pane (Resizable, initially 25%): The Agent**
    - **Chat Interface:** A familiar chat UI for interacting with the AI agent. Messages from the agent that include tool calls or results will be visually distinct.
- **Bottom Pane (Collapsible): The Terminal**
    - An interactive terminal that can be opened, closed, or resized by the user. It will be used for running project-related commands.

### Workflow Breakdown:

1.  **Project Creation:**
    - A "New Project" button opens a modal.
    - Inside the modal is a **temporary chat session** with the AI to brainstorm and define the project (e.g., "I want to build a snake game in Python").
    - This chat is **not saved** to the database.
    - Once the user and AI agree on the project idea, the user confirms, and a new entry is created in the `projects` table.
2.  **Main Build View:**
    - The user is navigated to the main build screen with the layout described above.
    - The user can start chatting with the agent (e.g., "Create the basic file structure for me").
    - The agent performs actions (e.g., creating `main.py`, `utils.py`). These actions are logged as messages in the chat and reflected in the file tree.
    - The user can click on a file in the tree to open it in the Monaco editor.
3.  **Checkpointing:**
    - The user can name and save the current state of all project files as a "checkpoint."
    - The AI can also suggest creating a checkpoint after completing a significant task.
    - Users can view a list of checkpoints and choose to revert the entire project to a previous state.

## 3. Database Schema

This schema is designed to support the features above, especially agent tool usage and file checkpointing.

### Enum Types
```sql
CREATE TYPE message_sender AS ENUM ('user', 'ai');
CREATE TYPE agent_message_type AS ENUM ('text', 'tool_request', 'tool_result', 'error');
CREATE TYPE file_operation_type AS ENUM ('create', 'update', 'delete');
```

### Core Tables

| Table                 | Purpose                                                                                             |
| --------------------- | --------------------------------------------------------------------------------------------------- |
| `projects`            | Stores the master list of all user-created projects.                                                |
| `agent_chats`         | A project can have multiple chat sessions with the agent.                                           |
| `agent_chat_messages` | Stores individual messages, including complex agent actions and checkpoint flags.                   |
| `project_files`       | Stores the **current state** of every file in a project. This table is the "source of truth".       |
| `file_checkpoints`    | Stores a snapshot of a project's file state at a specific point in time.                            |
| `checkpoint_files`    | Contains the actual content of each file at the time a checkpoint was created.                      |
| `file_operations`     | Logs every file change made by the agent, providing a detailed history for auditing or rollbacks.   |

### Table Definitions

**`projects`**
```sql
CREATE TABLE public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  stack TEXT[], -- e.g., {'Flutter', 'Supabase', 'Riverpod'}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**`agent_chats`**
```sql
CREATE TABLE public.agent_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**`agent_chat_messages`**
```sql
CREATE TABLE public.agent_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.agent_chats(id) ON DELETE CASCADE,
  sender message_sender NOT NULL,
  message_type agent_message_type NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  tool_calls JSONB, -- Stores agent's requested tool calls
  tool_results JSONB, -- Stores the results of those tool calls
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
```

**`project_files`**
```sql
CREATE TABLE public.project_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  path TEXT NOT NULL, -- Full path, e.g., 'lib/src/app.dart'
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_modified TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (project_id, path)
);
```

**`file_checkpoints`**
```sql
CREATE TABLE public.file_checkpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.agent_chat_messages(id) ON DELETE SET NULL, -- Optional link to the message that prompted the checkpoint
  name TEXT NOT NULL, -- e.g., "Initial setup", "Implemented feature X"
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**`checkpoint_files`**
```sql
CREATE TABLE public.checkpoint_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkpoint_id UUID NOT NULL REFERENCES public.file_checkpoints(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  content TEXT NOT NULL
);
```

**`file_operations`**
```sql
CREATE TABLE public.file_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.agent_chat_messages(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  operation_type file_operation_type NOT NULL,
  path TEXT NOT NULL,
  old_content TEXT, -- For 'update' and 'delete' operations
  new_content TEXT, -- For 'create' and 'update' operations
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```
