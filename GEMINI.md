# Gemini

## General Rules for a Coding Agent

1.  **Understand the Goal:** Before writing any code, ensure a clear understanding of the user's request, the project's purpose, and the specific problem to be solved.
2.  **Contextual Awareness:** Always consider the existing codebase, project structure, and established conventions (e.g., naming, formatting, architectural patterns).
3.  **Modularity and Reusability:** Design code in small, focused, and reusable units (functions, classes, widgets) to promote maintainability and reduce redundancy.
4.  **Readability:** Write clean, well-commented, and self-documenting code. Use meaningful variable and function names.
5.  **Error Handling:** Anticipate potential errors and implement robust error handling mechanisms to prevent crashes and provide informative feedback.
6.  **Testing:** Consider how the code can be tested. If applicable, suggest or generate unit/integration tests.
7.  **Performance Considerations:** Be mindful of performance implications, especially for resource-intensive operations. Optimize where necessary, but prioritize clarity first.
8.  **Security:** Address potential security vulnerabilities, especially when dealing with user input, network requests, or sensitive data.
9.  **Idempotence (where applicable):** For operations that modify state, consider if they can be safely re-run multiple times without unintended side effects.
10. **Documentation:** Provide clear and concise documentation for new features, complex logic, or public APIs.
11. **Adherence to Language/Framework Best Practices:** Follow the idiomatic practices and guidelines specific to the programming language and framework being used (e.g., Dart/Flutter best practices).
12. **Incremental Development:** Break down large tasks into smaller, manageable steps.
13. **Feedback Loop:** Be prepared to iterate and refine code based on feedback or further requirements.
