# Robin App: Design System & Language

This document outlines the design principles, color palette, typography, and component styles for the Robin application. The goal is to create a modern, minimal, and visually stunning user experience.

## 1. Core Principles

-   **Minimalism & Focus**: The design prioritizes content and clarity. We use a pitch-black background, generous whitespace, and a strong typographic hierarchy to guide the user's attention. Clutter is actively avoided.
-   **Glassmorphism & Glow**: We use subtle `BackdropFilter` effects, soft glows, and semi-transparent elements to create a sense of depth and a futuristic, premium feel. This is applied to modals and secondary UI surfaces.
-   **Intentional Animation**: Animations and micro-interactions (like hover effects) are used purposefully to provide feedback, confirm actions, and add a layer of polish. They should be fluid and non-intrusive.
-   **User-Centric**: The design is built around the user's intent. The `HomeScreen` immediately presents the core actions, and subsequent pages are designed to be intuitive and task-oriented.

## 2. Color Palette

-   **Primary Background**: `Colors.black` (#000000) - A true, deep black for a high-contrast, immersive experience.
-   **Primary Accent**: `Colors.blueAccent` - Used for primary buttons, highlights, and interactive elements.
-   **Secondary Surfaces**: `Colors.white.withOpacity(0.05)` to `0.1` - Used for cards and modals to create a subtle separation from the background.
-   **Borders**: `Colors.white.withOpacity(0.1)` to `0.2` - Used to define the edges of cards and components.
-   **Text (Primary)**: `Colors.white` - For headings and key information.
-   **Text (Secondary)**: `Colors.white.withOpacity(0.7)` or `Colors.white70` - For subtitles, descriptions, and less important text.
-   **Destructive Action**: `Colors.redAccent` - Used for actions like "Sign Out".

## 3. Typography

-   **Primary Font**: **Poppins** (via `google_fonts`).
-   **Headings (e.g., Page Titles)**: Large font size (48-64px), bold weight (`w600`), and tight line height (`1.1-1.2`).
-   **Subheadings & Body Text**: Regular to medium weight (`w400`-`w500`), with a comfortable line height (`1.5`).
-   **Buttons & UI Elements**: Medium weight (`w500`) to ensure readability.

## 4. Component Design Guide

-   **Action Buttons (`HomeScreen`)**: Large, interactive cards with a prominent icon. They should have a subtle hover effect (e.g., a growing border glow or slight scale).
-   **Modals (`SettingsProfileModal`)**: Should always appear over a blurred background (`BackdropFilter`). The modal itself is a semi-transparent card with a defined border. The layout should be clean and organized, using tabs or lists for navigation.
-   **In-Section Pages (`Build`/`Learn`)**:
    -   **Layout**: A distinct "two-halves" layout. The left side is for context and primary actions, while the right side is for content and lists.
    -   **"New Item" Card**: A key component. It should feature a dashed border and a central `+` icon to clearly signify its purpose of creation.
    -   **Content Lists (Right Half)**: The right side will contain a scrollable list of custom cards. Each card should be visually appealing, with a title, a short description or status, and relevant icons (e.g., tech stack for a project). They should have a subtle hover effect.
-   **Tooltips (`CustomTooltip`)**:
    -   **Style**: Dark, semi-transparent background with a light border.
    -   **Behavior**: A 1-second delay (`waitDuration`) to prevent them from appearing intrusively for experienced users.

This design system will ensure that as we build out new features, the app remains cohesive, beautiful, and intuitive.
