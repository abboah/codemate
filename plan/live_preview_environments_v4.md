# Plan V4: Live Preview Environments with Docker & Tunneling

This document outlines the architecture for a "Live Preview" feature capable of running any backend application (e.g., Python/Flask, Java/Spring, non-web Node.js) by provisioning dedicated, secure backend containers. This is a powerful, universal solution that requires a significant investment in infrastructure.

**Prerequisite:** This plan is a long-term vision, intended to be implemented after the core IDE, VFS, and basic execution (V1/V2) are mature.

---

## The Core Concept: A Personal, Sandboxed Cloud Environment

The goal is to give each user a temporary, secure, and isolated Linux environment in the cloud where their code can run. We achieve this by combining three key technologies:

1.  **Docker:** To create and manage the isolated, sandboxed containers.
2.  **An Orchestration Service:** A central backend service that we build to manage the entire lifecycle of these containers.
3.  **A Tunneling Service:** To securely expose the port from the user's running application inside the container to a public URL.

**The User Experience:**
1.  A user with a Python Flask project clicks "Run Live Server."
2.  The Codemate IDE sends a request to our backend Orchestrator.
3.  The Orchestrator spins up a new Docker container, copies the user's code into it, runs `pip install -r requirements.txt`, and then executes `flask run`.
4.  The Orchestrator starts a tunneling service (like ngrok) that points to the Flask server's port inside the container.
5.  The public URL (e.g., `https://random-hash.ngrok.io`) is sent back to the user's IDE.
6.  A new "Preview" pane opens, showing the live output of their Flask application.

---

## Architectural Components

### 1. The Orchestration Service
This is the brain of the operation. It would be a stateful backend service (e.g., a Node.js/Express or Go application running on a dedicated virtual machine or in a Kubernetes cluster). Its responsibilities include:
*   **API Endpoints:** Exposing a secure API for the Flutter client (e.g., `/instances/start`, `/instances/stop`).
*   **Instance Management:** Maintaining a record of active user sessions and their corresponding container IDs.
*   **Docker Integration:** Communicating with the Docker Engine to create, start, stop, and destroy containers.
*   **File Syncing:** Pulling project files from the Supabase VFS and injecting them into the correct container.
*   **Tunneling Management:** Programmatically starting and stopping tunnels for each instance.

### 2. The Container Environment
*   **Base Images:** We would maintain a set of base Docker images for different technology stacks (e.g., `codemate/python:3.11`, `codemate/node:20`). These images would come pre-installed with common tools and dependencies to speed up startup time.
*   **Resource Limits:** Each container would be run with strict CPU and memory limits to prevent abuse and manage costs.

### 3. The Tunneling Service
*   **ngrok (Easy Start):** The ngrok agent can be run by the Orchestrator to easily generate a public URL for each container.
*   **Cloudflare Tunnels (Robust Scale):** A more production-ready solution that offers better performance, security, and management features.

---

## Implementation Sprints

This is a major undertaking, broken into several high-level sprints.

### **Sprint 1: The Orchestrator MVP**
**Objective:** Build the core service that can manage a "pool" of containers.
*   Set up a dedicated server (e.g., a DigitalOcean Droplet or AWS EC2 instance).
*   Develop the initial Express.js (or similar) application for the Orchestrator.
*   Create API endpoints for `/start` and `/stop`.
*   Implement the logic to communicate with the Docker Engine to start a pre-defined container from a base image.

### **Sprint 2: VFS to Container Sync**
**Objective:** Implement the logic to get project files into the running containers.
*   When the `/start` endpoint is called, the Orchestrator will:
    1.  Query the Supabase `project_files` table for the given `projectId`.
    2.  Create a temporary directory on the host machine.
    3.  Write the fetched files to this directory.
    4.  Use Docker's `COPY` command or volume mounting to make these files available inside the newly created container.

### **Sprint 3: Tunneling and Client Integration**
**Objective:** Expose the running application and connect the Flutter client.
*   Integrate the ngrok (or other) API into the Orchestrator. When a container starts a web server on a port, the Orchestrator will detect it and start a tunnel.
*   The `/start` endpoint will now return the public URL to the Flutter client.
*   The Flutter client will be updated to include a "Live Preview" pane, which will house a webview (`iframe`) pointed at the URL returned by the Orchestrator.

### **Sprint 4: Lifecycle Management & Security**
**Objective:** Implement crucial features for managing costs and security.
*   **Idle Timeout:** The Orchestrator will track user activity. If an instance has been idle for a set period (e.g., 30 minutes), its container will be automatically stopped and destroyed to save resources.
*   **Resource Monitoring:** Implement monitoring to track CPU and memory usage across all running containers.
*   **Security Hardening:** Implement network policies to prevent containers from accessing the host machine or other containers. Ensure all communication with the Orchestrator is authenticated and authorized.

This V4 architecture provides the ultimate flexibility, allowing you to run any kind of application for your users, but it requires a dedicated and significant engineering effort to build and maintain.
