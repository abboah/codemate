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

// Master list of all available tools for the agent
export const availableTools = [createFileTool, updateFileTool, deleteFileTool, readFileTool, searchTool];