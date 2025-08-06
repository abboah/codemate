-- Python Course Topics (22 total: 10 + project + 10 + final project)
INSERT INTO public.topics (course_id, title, description, topic_order, topic_type, estimated_time_minutes)
SELECT 
  c.id as course_id,
  t.title,
  t.description,
  t.topic_order,
  t.topic_type::topic_type,
  t.estimated_time_minutes
FROM public.courses c
CROSS JOIN (
  VALUES
    -- First 10 regular topics
    (1, 'Getting Started with Python', 'Install Python, set up your development environment, and write your first program.', 'regular', 90),
    (2, 'Variables and Data Types', 'Learn about integers, floats, strings, booleans, and how to work with different data types.', 'regular', 100),
    (3, 'Input and Output', 'Master user input, string formatting, and displaying output in various formats.', 'regular', 85),
    (4, 'Control Flow: Conditionals', 'Use if, elif, and else statements to make decisions in your programs.', 'regular', 95),
    (5, 'Control Flow: Loops', 'Implement for and while loops to repeat code efficiently.', 'regular', 110),
    (6, 'Functions', 'Create reusable code blocks with parameters, return values, and scope concepts.', 'regular', 120),
    (7, 'Data Structures: Lists', 'Work with Python lists, including indexing, slicing, and list methods.', 'regular', 105),
    (8, 'Data Structures: Dictionaries', 'Master key-value pairs, dictionary methods, and practical applications.', 'regular', 100),
    (9, 'String Manipulation', 'Advanced string operations, methods, and text processing techniques.', 'regular', 90),
    (10, 'Error Handling', 'Learn to handle exceptions gracefully with try-except blocks.', 'regular', 95),
    
    -- First capstone project
    (11, 'Capstone Project: Personal Finance Tracker', 'Build a command-line application to track income, expenses, and generate financial reports using all concepts learned so far.', 'project', 180),
    
    -- Next 10 regular topics
    (12, 'File I/O Operations', 'Read from and write to files, handle different file formats and paths.', 'regular', 110),
    (13, 'Object-Oriented Programming: Classes', 'Introduction to classes, objects, attributes, and methods.', 'regular', 130),
    (14, 'Object-Oriented Programming: Inheritance', 'Implement inheritance, method overriding, and polymorphism.', 'regular', 120),
    (15, 'Working with Modules', 'Import and use built-in modules, create custom modules, and understand packages.', 'regular', 100),
    (16, 'Regular Expressions', 'Pattern matching and text processing with the re module.', 'regular', 115),
    (17, 'Working with APIs', 'Make HTTP requests, parse JSON data, and integrate external services.', 'regular', 125),
    (18, 'Database Connectivity', 'Connect to databases, execute queries, and manage data persistence.', 'regular', 135),
    (19, 'Testing and Debugging', 'Write unit tests, debug code effectively, and ensure code quality.', 'regular', 110),
    (20, 'Popular Libraries Overview', 'Introduction to NumPy, Pandas, Requests, and other essential libraries.', 'regular', 140),
    (21, 'Best Practices and Code Style', 'PEP 8 guidelines, code organization, documentation, and professional practices.', 'regular', 95),
    
    -- Final capstone project
    (22, 'Final Project: Data Analysis Web Scraper', 'Create a comprehensive application that scrapes web data, processes it with pandas, stores results in a database, and generates analytical reports.', 'project', 240)
) AS t(topic_order, title, description, topic_type, estimated_time_minutes)
WHERE c.name = 'Python';












-- JavaScript Course Topics (22 total: 10 + project + 10 + final project)
INSERT INTO public.topics (course_id, title, description, topic_order, topic_type, estimated_time_minutes)
SELECT 
  c.id as course_id,
  t.title,
  t.description,
  t.topic_order,
  t.topic_type::topic_type,
  t.estimated_time_minutes
FROM public.courses c
CROSS JOIN (
  VALUES
    -- First 10 regular topics
    (1, 'JavaScript Fundamentals', 'Set up your environment, understand JavaScript syntax, and write your first scripts.', 'regular', 100),
    (2, 'Variables and Data Types', 'Learn about let, const, var, and JavaScript''s dynamic typing system.', 'regular', 95),
    (3, 'Operators and Expressions', 'Master arithmetic, comparison, logical, and assignment operators.', 'regular', 90),
    (4, 'Control Structures', 'Implement if-else statements, switch cases, and conditional logic.', 'regular', 105),
    (5, 'Loops and Iteration', 'Use for, while, do-while loops, and modern iteration methods.', 'regular', 110),
    (6, 'Functions', 'Create functions with parameters, return values, and understand function scope.', 'regular', 120),
    (7, 'Arrays', 'Work with JavaScript arrays, indexing, and essential array methods.', 'regular', 115),
    (8, 'Objects', 'Create and manipulate objects, understand properties and methods.', 'regular', 110),
    (9, 'Strings and Template Literals', 'Advanced string manipulation and modern template literal syntax.', 'regular', 95),
    (10, 'DOM Basics', 'Introduction to the Document Object Model and basic element manipulation.', 'regular', 125),
    
    -- First capstone project
    (11, 'Capstone Project: Interactive To-Do List', 'Build a dynamic to-do list application with DOM manipulation, local storage, and interactive features.', 'project', 200),
    
    -- Next 10 regular topics
    (12, 'Events and Event Handling', 'Handle user interactions with click, input, and other event listeners.', 'regular', 130),
    (13, 'Advanced Functions', 'Arrow functions, callbacks, higher-order functions, and closures.', 'regular', 140),
    (14, 'Asynchronous JavaScript: Promises', 'Understand asynchronous programming with Promises and then/catch.', 'regular', 150),
    (15, 'Async/Await', 'Modern asynchronous syntax and error handling with async/await.', 'regular', 135),
    (16, 'Fetch API and AJAX', 'Make HTTP requests, handle responses, and work with external APIs.', 'regular', 145),
    (17, 'Error Handling', 'Implement try-catch blocks and proper error management strategies.', 'regular', 100),
    (18, 'ES6+ Features', 'Destructuring, spread operator, modules, and modern JavaScript features.', 'regular', 160),
    (19, 'Local Storage and Session Storage', 'Client-side data persistence and browser storage APIs.', 'regular', 115),
    (20, 'Regular Expressions in JavaScript', 'Pattern matching, validation, and text processing with regex.', 'regular', 120),
    (21, 'JavaScript Best Practices', 'Code organization, debugging techniques, and performance optimization.', 'regular', 110),
    
    -- Final capstone project
    (22, 'Final Project: Weather Dashboard App', 'Create a comprehensive weather application that fetches data from APIs, displays dynamic content, handles user preferences, and implements responsive design.', 'project', 280)
) AS t(topic_order, title, description, topic_type, estimated_time_minutes)
WHERE c.name = 'JavaScript';




 -- More have been added, But I just did this as a preview for you


