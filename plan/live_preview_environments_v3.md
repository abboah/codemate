# Plan V3: Live Preview Environments with WebContainers

This document outlines the implementation of a "Live Preview" feature for web development projects (e.g., React, Node.js, Vue) using StackBlitz's WebContainer API. This approach provides a seamless, in-browser development server experience without requiring a complex containerized backend.

**Prerequisite:** This plan assumes the completion of the V1 and V2 plans for the terminal and core IDE functionality.

---

## The Core Concept: In-Browser Node.js

WebContainers are a technology that boots a full Node.js runtime environment, including a file system and terminal, entirely within the user's web browser using WebAssembly. This is a revolutionary approach that eliminates the need for backend virtual machines or Docker containers for web development use cases, drastically reducing complexity and cost.

**The User Experience:**
1.  The user has a React project open in the Codemate IDE.
2.  They click a "Run Live Preview" button.
3.  A new pane appears in the IDE, showing a browser preview.
4.  Behind the scenes, a WebContainer instance boots, runs `npm install`, and then `npm run dev`.
5.  The preview pane renders the output of the development server (e.g., `localhost:5173`).
6.  When the user edits a file in the Codemate editor, the change is sent to the WebContainer's virtual file system, and the preview pane automatically hot-reloads, just like a local development environment.

---

## Implementation Sprints

### **Sprint 1: Integrating the WebContainer API**

**Objective:** Set up the basic communication between our Flutter app and the WebContainer API.

**Step 1.1: Add the WebContainer API Package**
We will need a way for our Flutter web app to interact with the JavaScript-based WebContainer API. We'll use the `js` package to facilitate this.

**Step 1.2: Create the WebContainer Service**
*   **Create file:** `lib/services/web_container_service.dart`
    *   This service will be a wrapper around the JavaScript interoperability layer. It will expose methods like `boot()`, `spawn()`, `fs.writeFile()`, and `on('server-ready')`.

    ```dart
    // lib/services/web_container_service.dart (conceptual)
    import 'package:js/js.dart';

    @JS('WebContainer.boot')
    external Future<dynamic> _boot();

    class WebContainerService {
      dynamic _webcontainerInstance;

      Future<void> boot() async {
        _webcontainerInstance = await _boot();
      }

      // ... other methods to interact with the instance
    }
    ```

**Step 1.3: Create the Live Preview Widget**
*   **Create file:** `lib/components/ide/live_preview_view.dart`
    *   This widget will be responsible for housing the `iframe` where the live preview will be rendered.
    *   It will interact with the `WebContainerService` to get the preview URL.

### **Sprint 2: Bootstrapping the Project**

**Objective:** Load the user's project from our Supabase VFS into the WebContainer's virtual file system.

**Step 2.1: Fetch Project Files**
When the user clicks "Run Live Preview," the app will first fetch all files for the current project from the `ProjectFilesProvider`.

**Step 2.2: Write Files to the WebContainer VFS**
We will loop through the project files and use the `webcontainerInstance.fs.writeFile()` method (exposed via our `WebContainerService`) to populate the virtual file system inside the browser.

```dart
// Conceptual logic inside a method in LivePreviewView
Future<void> _loadProjectIntoWebContainer(List<ProjectFile> files) async {
  final fileSystemPayload = {
    'package.json': {
      'file': { 'contents': '...' }
    },
    'src': {
      'directory': {
        'index.js': {
          'file': { 'contents': '...' }
        }
      }
    }
  };
  // The WebContainer API can mount a full directory structure at once.
  // We will transform our flat list of files into this nested map structure.
  await _webContainerService.mount(fileSystemPayload);
}
```

### **Sprint 3: Running the Dev Server and Displaying the Preview**

**Objective:** Execute the development server and render its output.

**Step 3.1: Run `npm install`**
Once the files are mounted, we will use the `spawn` method to run the installation command.

```dart
// Conceptual logic
final installProcess = await _webContainerService.spawn('npm', ['install']);
// We can stream the output of this process to our simulated terminal view
installProcess.output.listen((data) => terminalProvider.addOutput(data));
await installProcess.exit;
```

**Step 3.2: Run the Dev Server**
After installation, we run the development server command (e.g., `npm run dev`).

```dart
// Conceptual logic
await _webContainerService.spawn('npm', ['run', 'dev']);
```

**Step 3.3: Listen for the Server-Ready Event**
The WebContainer API provides a crucial event listener that tells us when the internal server is ready and provides the URL.

```dart
// Conceptual logic
_webContainerService.onServerReady((port, url) {
  // The URL will be something like 'https://localhost:5173'
  // We set this URL as the source for our iframe in the LivePreviewView
  setState(() {
    _previewUrl = url;
  });
});
```

The `LivePreviewView` widget will then render an `iframe` pointed to this `_previewUrl`, completing the magic loop. This architecture provides an incredibly powerful live preview feature for web projects with minimal backend infrastructure cost and complexity.
