# Robin App Revamp: Plan & Strategy

This document outlines the plan to revamp the Robin application, focusing on a minimal design, a new onboarding experience, and a more intuitive user flow.

## 1. Core Philosophy

The goal is to shift from a dense, feature-heavy dashboard to a clean, focused, and welcoming user experience. The new design will prioritize user intent, guiding them immediately toward one of three core actions: **Build**, **Learn**, or **Chat**.

## 2. New Branch & Font

-   **Branch**: All work will be done on the `new-layout` branch to ensure the `main` branch remains stable.
-   **Signature Font**: We will use **Poppins** as the primary font for headings and key UI elements to give the app a fresh, modern, and friendly feel. We will integrate it using the `google_fonts` package.

## 3. Onboarding Experience

-   **Problem**: New users are currently dropped directly into a complex dashboard, which can be overwhelming.
-   **Solution**: Upon first login, a new user will be greeted with a **Tour Guide**.
    -   **Implementation**: This will be a modal overlay with a `BackdropFilter` for a blur effect.
    -   The tour will consist of 2-3 simple steps, highlighting the `Build`, `Learn`, and `Chat` sections.
    -   We will need a mechanism to track if a user has completed the tour (e.g., a flag in their Supabase user profile).

## 4. The New Dashboard

-   **Layout**: The complex sidebar and multi-panel dashboard will be replaced.
-   **Greeting**: The centerpiece will be a large, friendly greeting: `"Hi there, {user_name}! What will you work on today?"`
-   **Core Actions**: Below the greeting, three prominent, visually appealing buttons/sections will be displayed:
    1.  **Build**: For project-based AI assistance.
    2.  **Learn**: For accessing learning pathways and courses.
    3.  **Chat**: For general-purpose AI conversation.
-   **Top Navigation**:
    -   A user avatar will be in the top-right corner.
    -   Clicking the avatar will open a dropdown/modal for `Account`, `Settings`, and `Logout`.
    -   The `Account` and `Settings` pages will open as modals with a blur backdrop, similar to the existing password reset dialogs.

## 5. Core Section Pages (Build, Learn, Chat)

### A. Build & Learn Pages

These two pages will share a consistent, two-column layout to promote a familiar user experience.

-   **Left Column**:
    -   A large, bold title (e.g., "**Build**" or "**Learn**").
    -   A primary action button below the title ("+ New Project" or "Browse Courses").
-   **Right Column (Main Content Area)**:
    -   A list of the user's existing items (projects or in-progress courses).
    -   Each item will be a clickable card, leading to its detailed view.
-   **Navigation**: A "Back to Dashboard" button will be clearly visible at the top of the page.

### B. Chat Page

-   This will reuse and refine the existing chatbot UI from `lib/chatbot/chatbot.dart`.
-   The focus will be on a clean, conversational interface.
-   It will also have a "Back to Dashboard" navigation button.

## 6. Implementation Steps

1.  **Setup**:
    -   Add the `google_fonts` package to `pubspec.yaml`.
    -   Create the new branch `new-layout`.
2.  **Create New Dashboard**:
    -   Build the main widget for the new minimal dashboard.
    -   Implement the central greeting and the three action buttons (`Build`, `Learn`, `Chat`).
3.  **Update Navigation & Routing**:
    -   Modify `AuthGate` to direct authenticated users to the new dashboard.
    -   Set up routes for the `Build`, `Learn`, and `Chat` pages.
4.  **Build the "Build" & "Learn" Pages**:
    -   Create a reusable two-column layout widget.
    -   Implement the "Build" page, including the "New Project" button and a placeholder for the project list.
    -   Implement the "Learn" page, reusing components from the existing `LearningHub` where possible.
5.  **Implement Onboarding Tour**:
    -   Create the tour guide widget as a stateful overlay.
    -   Add logic to `AuthGate` or the new dashboard to show it only once for new users.
6.  **Refine Profile & Settings Modals**:
    -   Implement the top-right avatar and the popup menu.
    -   Create the `Account` and `Settings` modals.
7.  **Security**:
    -   **Crucial**: Move the hardcoded Gemini API key from `chatbot.dart` to the `.env` file and load it securely.

This plan provides a clear roadmap for transforming Robin into a more intuitive and powerful coding assistant and learning partner.
