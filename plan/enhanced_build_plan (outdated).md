## UI Architecture

### Primary Layout Structure
```
┌─────────────────────────────────────────┐
│  [Agent] ●○ [Code]  (Toggle Pills)     │
├─────────────────────────────────────────┤
│                                         │
│  AGENT VIEW          │  CODE VIEW       │
│  ┌─────────────────┐ │  ┌─────────────┐ │
│  │ Chat Messages   │ │  │ File Tree   │ │
│  │                 │ │  │             │ │
│  │ [Code Preview]  │ │  └─────────────┘ │
│  │ ┌─────────────┐ │ │                  │
│  │ │// main.dart │ │ │  ┌─────────────┐ │
│  │ │class App... │ │ │  │   Tabs      │ │
│  │ │   Click →   │ │ │  │ main.dart × │ │
│  │ └─────────────┘ │ │  │ utils.dart× │ │
│  │                 │ │  └─────────────┘ │
│  │ Input Field     │ │                  │
│  └─────────────────┘ │  ┌─────────────┐ │
│                       │  │ Code Editor │ │
│                       │  │             │ │
│                       │  └─────────────┘ │
└─────────────────────────────────────────┘
```

### Flutter Widget Hierarchy
```dart
BuildPage
├── TogglePills (Agent/Code)
├── PageView or AnimatedSwitcher
    ├── AgentView
    │   ├── ChatMessagesList
    │   │   ├── MessageBubble
    │   │   └── CodePreviewCard (clickable)
    │   └── ChatInput
    └── CodeView
        ├── FileTreePanel (left sidebar)
        ├── TabsBar
        └── CodeEditor
```

## Enhanced Database Schema

Let me extend your schema to support the file management and project structure:

### Projects & Files
```sql
-- Your existing projects table
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name TEXT NOT NULL,
  description TEXT,
  project_type TEXT DEFAULT 'flutter', -- flutter, react, python, etc.
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Files within projects
CREATE TABLE project_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL, -- e.g., 'lib/main.dart', 'pubspec.yaml'
  file_name TEXT NOT NULL, -- e.g., 'main.dart'
  content TEXT,
  file_type TEXT, -- 'dart', 'yaml', 'json', etc.
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(project_id, file_path)
);

-- Link chats to specific projects
ALTER TABLE agent_chats ADD COLUMN project_id UUID REFERENCES projects(id);
```

### Enhanced Messages for Tool Usage
```sql
-- Extend your messages table
ALTER TABLE messages ADD COLUMN tool_calls JSONB; -- Store tool invocations
ALTER TABLE messages ADD COLUMN tool_results JSONB; -- Store tool results
ALTER TABLE messages ADD COLUMN metadata JSONB; -- File changes, previews, etc.

-- Track file operations
CREATE TABLE file_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES messages(id),
  project_id UUID REFERENCES projects(id),
  operation_type TEXT CHECK (operation_type IN ('create', 'edit', 'delete')),
  file_path TEXT NOT NULL,
  old_content TEXT, -- For edits/deletes
  new_content TEXT, -- For creates/edits
  diff_data JSONB, -- Store diff information
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Project Sessions & Collaboration
```sql
-- Track active editing sessions
CREATE TABLE project_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id),
  user_id UUID REFERENCES users(id),
  active_file_path TEXT,
  cursor_position JSONB, -- Line, column info
  last_activity TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);
```

## Flutter Implementation Strategy

### 1. State Management (Riverpod/Bloc)
```dart
// Project state
class ProjectState {
  final Project project;
  final List<ProjectFile> files;
  final String? activeFilePath;
  final List<ChatMessage> messages;
  final bool isAgentView;
}

// Key providers
final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>();
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>();
final fileTreeProvider = Provider<List<ProjectFile>>();
```

### 2. Core Features Implementation

**Code Preview Cards in Chat:**
```dart
class CodePreviewCard extends StatelessWidget {
  final String fileName;
  final String codeSnippet;
  final VoidCallback onTap;
  
  Widget build(context) {
    return GestureDetector(
      onTap: () {
        // Switch to code view and open file
        ref.read(projectProvider.notifier).setActiveFile(fileName);
        ref.read(projectProvider.notifier).switchToCodeView();
      },
      child: Container(
        // Styled preview with syntax highlighting
      ),
    );
  }
}
```

**File Tree Component:**
```dart
class FileTreePanel extends StatelessWidget {
  Widget build(context) {
    return TreeView(
      nodes: _buildFileTree(files),
      onNodeTap: (node) => _openFile(node.path),
    );
  }
}
```

### 3. Gemini Integration Architecture
```dart
class GeminiService {
  Future<ChatResponse> sendMessage(String message, List<Tool> tools) async {
    // Handle tool calls: create_file, edit_file, delete_file
  }
  
  Future<void> executeToolCall(ToolCall toolCall) async {
    switch (toolCall.name) {
      case 'create_file':
        await _createFile(toolCall.parameters);
        break;
      case 'edit_file':
        await _editFile(toolCall.parameters);
        break;
      case 'delete_file':
        await _deleteFile(toolCall.parameters);
        break;
    }
  }
}
```

## UI/UX Enhancements

### 1. Smooth Transitions
- Use `AnimatedSwitcher` for Agent/Code toggle
- Implement slide animations for file tabs
- Add subtle loading states during AI processing

### 2. Code Preview Integration
```dart
// In chat messages, detect code blocks and make them interactive
class ChatMessage extends StatelessWidget {
  Widget _buildCodeBlock(String code, String? fileName) {
    return CodePreviewCard(
      code: code,
      fileName: fileName,
      onTap: () => _navigateToCode(fileName),
    );
  }
}
```

### 3. Real-time Collaboration Features
- File conflict resolution UI
- Live cursor indicators
- Change notifications

### 4. Mobile-First Considerations
```dart
// Responsive design for smaller screens
class BuildPageLayout extends StatelessWidget {
  Widget build(context) {
    final isTablet = MediaQuery.of(context).size.width > 768;
    
    return isTablet 
      ? _buildTabletLayout() 
      : _buildMobileLayout(); // Stack views instead of side-by-side
  }
}
```

This architecture gives you a solid foundation for your collaborative build environment. The key advantages:

1. **Seamless Integration**: Chat and code editing feel like one unified experience
2. **Context Preservation**: File operations are tracked and can be referenced in chat
3. **Scalable**: Database design supports multiple project types and collaboration
4. **Mobile-Optimized**: Flutter-native components work well across devices
