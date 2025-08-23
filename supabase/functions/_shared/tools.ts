import { FunctionDeclaration, Part, Schema, Type } from "https://esm.sh/@google/genai";

/**
 * Defines the tool for creating a new file in the project.
 */
export const createFileTool: FunctionDeclaration = {
  name: "create_file",
  description: "Creates a new file with a specified path and initial content. Use this to create new project files.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: "The full, unique path of the file to create, e.g., 'lib/main.dart' or 'src/components/button.tsx'.",
      },
      content: {
        type: Type.STRING,
        description: "The initial content of the file. Can be empty.",
      },
    },
    required: ["path", "content"],
  },
};

/**
 * Defines the tool for updating the content of an existing file.
 */
export const updateFileTool: FunctionDeclaration = {
  name: "update_file_content",
  description: "Updates the entire content of an existing file, identified by its unique path.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: "The unique path of the file to be updated.",
      },
      new_content: {
        type: Type.STRING,
        description: "The new, complete content that will overwrite the existing file content.",
      },
    },
    required: ["path", "new_content"],
  },
};

/**
 * Defines the tool for deleting a file.
 */
export const deleteFileTool: FunctionDeclaration = {
  name: "delete_file",
  description: "Permanently deletes a file from the project, identified by its unique path.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: "The unique path of the file to be deleted.",
      },
    },
    required: ["path"],
  },
};

/**
 * Defines the tool for reading a file's content.
 */
export const readFileTool: FunctionDeclaration = {
  name: "read_file",
  description: "Reads and returns the content of a file in the current project by its path.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: {
        type: Type.STRING,
        description: "The unique path of the file to read.",
      },
      max_bytes: {
        type: Type.NUMBER,
        description: "Optional maximum number of bytes to read for very large files. If omitted, returns full file.",
      },
    },
    required: ["path"],
  },
};

/**
 * Search across the entire project codebase for a query string.
 * Returns a list of files with matched lines and line numbers.
 */
export const searchTool: FunctionDeclaration = {
  name: "search",
  description: "Search the project files for lines containing a query (case-insensitive). Returns files and matching line numbers.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      query: { type: Type.STRING, description: "The substring or simple pattern to search for (no regex)." },
      max_results_per_file: { type: Type.NUMBER, description: "Optional cap for matches per file (default 20)." },
    },
    required: ["query"],
  },
};

/**
 * Project Card Preview tool: outputs a concise JSON schema for a simple, web-first project idea.
 * Guidance: Prefer web projects implemented with React or plain HTML/CSS/JS. Only use other stacks if the user asks or web is unsuitable.
 */
export const projectCardPreviewTool: FunctionDeclaration = {
  name: "project_card_preview",
  description: "Create a JSON template describing a simple, web-first project proposal with name, summary, stack, key_features, and whether it can be implemented as a single-file canvas component.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      name: { type: Type.STRING, description: "Short project name." },
      summary: { type: Type.STRING, description: "One-paragraph description of the project. Assume web target (React or HTML/CSS/JS) unless the user requested otherwise." },
      stack: { type: Type.ARRAY, description: "Suggested technologies (e.g., React, HTML/CSS/JS). Preserve this array for downstream usage.", items: { type: Type.STRING } },
      key_features: { type: Type.ARRAY, description: "List of 3-7 headline features.", items: { type: Type.STRING } },
      can_implement_in_canvas: { type: Type.BOOLEAN, description: "True if the project is web-based and can be implemented entirely in a single JS/HTML file for canvas preview; otherwise false." },
    },
    required: ["name", "summary"],
  },
};

/**
 * Todo list create tool
 */
export const todoListCreateTool: FunctionDeclaration = {
  name: "todo_list_create",
  description: "Create a structured todo list (JSON) from a user request, with sections and tasks.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      title: { type: Type.STRING, description: "Title of the todo list." },
      tasks: { type: Type.ARRAY, description: "Array of tasks with id, title, done flag.", items: { type: Type.OBJECT, properties: {
        id: { type: Type.STRING },
        title: { type: Type.STRING },
        done: { type: Type.BOOLEAN },
        notes: { type: Type.STRING },
      } } },
    },
    required: ["title"],
  },
};

/**
 * Todo list check tool
 */
export const todoListCheckTool: FunctionDeclaration = {
  name: "todo_list_check",
  description: "Update an existing todo list stored as a Playground artifact: mark completed tasks and optionally incorporate context.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      artifact_id: { type: Type.STRING, description: "ID of the todo list artifact in playground_artifacts." },
      completed_task_ids: { type: Type.ARRAY, description: "Optional array of task IDs to mark as done.", items: { type: Type.STRING } },
      context: { type: Type.STRING, description: "Optional context or recent changes to consider." },
    },
    required: ["artifact_id"],
  },
};

/**
 * Analyze document tool: accepts a file reference or base64 data and an instruction
 */
export const analyzeDocumentTool: FunctionDeclaration = {
  name: "analyze_document",
  description: "Analyze a user-provided document (PDF/images/others). Provide a concise summary or answer questions.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      source: { type: Type.STRING, description: "Either 'file_uri' or 'base64'." },
      file_uri: { type: Type.STRING, description: "Supabase storage public URL or Gemini Files API URI." },
      base64: { type: Type.STRING, description: "Base64 data if provided inline (<=20MB)." },
      mime_type: { type: Type.STRING, description: "MIME type, e.g., application/pdf, image/png." },
      instruction: { type: Type.STRING, description: "Instruction, e.g., 'summarize', 'extract tables', 'Q&A'." },
    },
    required: ["instruction"],
  },
};

/**
 * Generate image tool: delegates to an image-capable Gemini model and stores output
 */
export const generateImageTool: FunctionDeclaration = {
  name: "generate_image",
  description: "Generate an image from a text prompt using an image generation model. Returns storage path and public URL.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      prompt: { type: Type.STRING, description: "Image description to generate." },
      folder: { type: Type.STRING, description: "Optional storage folder (default 'playground/images')." },
      file_name: { type: Type.STRING, description: "Optional output file name (png)." },
    },
    required: ["prompt"],
  },
};

/**
 * Enhance image tool: improves an existing image using text instruction
 */
export const enhanceImageTool: FunctionDeclaration = {
  name: "enhance_image",
  description: "Enhance or edit an existing image given a public URL or base64 and an instruction.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      instruction: { type: Type.STRING, description: "How to improve the image (e.g., upscale, color grade)." },
      source: { type: Type.STRING, description: "Either 'file_uri' or 'base64'." },
      file_uri: { type: Type.STRING, description: "Public URL or Gemini Files API URI of image to enhance." },
      base64: { type: Type.STRING, description: "Base64 image data (<=20MB)." },
      mime_type: { type: Type.STRING, description: "MIME type for the source if base64 provided." },
      folder: { type: Type.STRING, description: "Optional storage folder to write enhanced image." },
      file_name: { type: Type.STRING, description: "Optional output filename (png)." },
    },
    required: ["instruction"],
  },
};

// Master list of all available tools for the agent (build/ask)
export const availableTools = [
  createFileTool,
  updateFileTool,
  deleteFileTool,
  readFileTool,
  searchTool,
];

// Master list including playground tools
export const playgroundTools = [
  projectCardPreviewTool,
  todoListCreateTool,
  todoListCheckTool,
  analyzeDocumentTool,
  generateImageTool,
  enhanceImageTool,
];

// Canvas tools for Playground (operate on per-chat canvas_files)
export const canvasCreateFileTool: FunctionDeclaration = {
  name: "canvas_create_file",
  description: "Create a new canvas file in the current Playground chat.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: { type: Type.STRING, description: "Unique path of the canvas file to create (e.g., 'canvas.md')." },
      content: { type: Type.STRING, description: "Initial content of the file." },
    },
    required: ["path", "content"],
  },
};

export const canvasUpdateFileTool: FunctionDeclaration = {
  name: "canvas_update_file_content",
  description: "Update entire content of an existing canvas file.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: { type: Type.STRING, description: "Path of the canvas file to update." },
      new_content: { type: Type.STRING, description: "New content to overwrite." },
    },
    required: ["path", "new_content"],
  },
};

export const canvasDeleteFileTool: FunctionDeclaration = {
  name: "canvas_delete_file",
  description: "Delete a canvas file from the current chat.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: { type: Type.STRING, description: "Path of the canvas file to delete." },
    },
    required: ["path"],
  },
};

export const canvasReadFileTool: FunctionDeclaration = {
  name: "canvas_read_file",
  description: "Read a canvas file's content by path.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      path: { type: Type.STRING, description: "Path of the canvas file to read." },
      max_bytes: { type: Type.NUMBER, description: "Optional max bytes to read for large files." },
    },
    required: ["path"],
  },
};

export const canvasSearchTool: FunctionDeclaration = {
  name: "canvas_search",
  description: "Search within all canvas files of the current chat for a query.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      query: { type: Type.STRING, description: "Substring to search for (case-insensitive)." },
      max_results_per_file: { type: Type.NUMBER, description: "Optional cap per file (default 20)." },
    },
    required: ["query"],
  },
};

export const playgroundCanvasTools = [
  canvasCreateFileTool,
  canvasUpdateFileTool,
  canvasDeleteFileTool,
  canvasReadFileTool,
  canvasSearchTool,
];

/**
 * Composite tool: Create a canvas file from a template stored in playground_artifacts.
 */
export const createFileFromTemplateTool: FunctionDeclaration = {
  name: "create_file_from_template",
  description: "Create a new canvas file (canvas_create_file) using a template stored as a playground artifact.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      artifact_id: { type: Type.STRING, description: "ID of the template artifact in playground_artifacts. The artifact data must contain a 'template' string." },
      path: { type: Type.STRING, description: "Destination canvas file path to create (e.g., 'component.js' or 'index.html')." },
      substitutions: { type: Type.OBJECT, description: "Optional key-value pairs to replace in the template (e.g., {{title}})." },
    },
    required: ["artifact_id", "path"],
  },
};

// Extend playground tools set with composites
export const playgroundCompositeTools = [
  createFileFromTemplateTool,
];

/**
 * Read a canvas file by its database ID (UUID).
 */
export const canvasReadFileByIdTool: FunctionDeclaration = {
  name: "canvas_read_file_by_id",
  description: "Read a canvas file's content using its database UUID.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      id: { type: Type.STRING, description: "UUID of the canvas file (public.canvas_files.id)" },
      max_bytes: { type: Type.NUMBER, description: "Optional max bytes to read for large files." },
    },
    required: ["id"],
  },
};

/**
 * Read a playground artifact by its ID (UUID).
 */
export const artifactReadTool: FunctionDeclaration = {
  name: "artifact_read",
  description: "Read a playground artifact's metadata and JSON data using its UUID.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      id: { type: Type.STRING, description: "UUID of the artifact (public.playground_artifacts.id)" },
    },
    required: ["id"],
  },
};

export const playgroundReadTools = [
  canvasReadFileByIdTool,
  artifactReadTool,
];

/**
 * Composite tool: Implement a feature by updating a canvas file and marking a todo task as done.
 */
export const implementFeatureAndUpdateTodoTool: FunctionDeclaration = {
  name: "implement_feature_and_update_todo",
  description: "Update a canvas file's content and then mark a corresponding task as completed in a stored todo list artifact.",
  parameters: {
    type: Type.OBJECT,
    properties: {
      artifact_id: { type: Type.STRING, description: "ID of the todo list artifact in playground_artifacts." },
      task_id: { type: Type.STRING, description: "ID of the task to mark as done." },
      path: { type: Type.STRING, description: "Canvas file path to update." },
      new_content: { type: Type.STRING, description: "New content to write into the canvas file." },
      context: { type: Type.STRING, description: "Optional notes/context about the implementation." },
    },
    required: ["artifact_id", "task_id", "path", "new_content"],
  },
};

// Also export in composites list
playgroundCompositeTools.push(implementFeatureAndUpdateTodoTool);