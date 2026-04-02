---
name: User profile
description: Senior React/TypeScript developer learning Flutter for the first time
type: user
---

Senior frontend developer with deep React and TypeScript expertise (including state management with Zustand/Redux). New to Flutter and Dart. Learns best through analogies to React patterns (JSX → build(), useSelector → ref.watch, Zustand store → Notifier, etc.). The codebase is already heavily annotated with these React/TS analogies to support this learning style.

## Workflow preferences
- **Always show active work**: Use TodoWrite to track tasks so progress is visible at all times.
- **Always re-read files before editing**: User makes manual changes frequently — never assume file contents are the same as last read. Re-read immediately before every edit.
- **Fast answers**: Keep responses concise and focused. Don't do side tasks (like running tests) unless explicitly asked.

Technical Specification: Wikipedia Explorer (Flutter Technical Assignment)
1. Context for the AI Assistant (Copilot)

Role: Act as a Senior Flutter Developer mentoring a Senior React/TypeScript Developer.
Goal: Generate a complete, production-ready Flutter application that fulfills a 3-hour technical assignment.
Constraint: Whenever generating code, include heavy inline comments that translate Dart/Flutter concepts into React, TypeScript, and Zustand/Redux terms. Ensure the code is clean, modular, and testable.
2. Project Overview

App Name: Wikipedia Explorer
Description: A cross-platform application that finds Wikipedia articles about nearby locations. It uses the device's GPS to find articles based on current coordinates, or allows the user to manually search by typing a city name.
Target Platforms: Android, iOS, and Web.
Time Limit: Must be simple enough to explain and build within a 3-hour window.
3. Core Requirements & User's Specific Requests

    Dual-Path Data Fetching (Permission Fallback):

        Path A: Request Location Permission. If granted, get GPS coordinates and fetch nearby Wikipedia articles.

        Path B (Fallback): If permission is denied, or the user prefers not to use GPS, provide a text input to manually enter a city name. Convert the city to coordinates (Geocoding), then fetch nearby Wikipedia articles.

    Cross-Platform: The code must compile and work seamlessly on Android, iOS, and Web.

    Accessibility (a11y): The app must be accessible. Use semantic labeling (e.g., the Semantics widget) where appropriate, just as one would use aria-labels in Web development.

    State Tracking (Assignment Requirement): Track and display the following state:

        isLoading (boolean)

        error (String?)

        apiCallCount (integer - total number of HTTP calls made)

        articles (List of fetched Wikipedia articles)

        history (List of article titles the user has tapped on during the session)

    Open Source APIs (No API Keys required):

        Wikipedia GeoSearch API: To fetch articles by Lat/Lng.

        Open-Meteo Geocoding API: To convert typed city names into Lat/Lng.

4. Architecture & Tech Stack

State Management: flutter_riverpod

    Use Notifier and NotifierProvider to manage global state.

    State must be immutable (using a copyWith method), mimicking a Zustand or Redux store.

    Keep business logic completely decoupled from the UI.

Networking: http

    Use Uri.https() for all endpoints to ensure parameters are properly encoded.

    Create an ApiService class to handle JSON fetching and decoding.

    Create strictly-typed Dart classes with fromJson factories for data models (mimicking TypeScript interfaces).

Hardware/Sensors: geolocator

    Used to request location permissions and get device GPS coordinates safely.

Utilities: url_launcher

    Used to open the Wikipedia article in the device's default web browser when tapped.

5. UI / UX Guidelines

    Search/Action Area: A prominent "Use My Location" button (ElevatedButton) and a manual Text Input (TextField) with a "Search City" button.

    Stats Dashboard: A small header showing the tracked state: "API Calls: X" and "History length: Y".

    Results View: A ListView.builder (equivalent to array.map()) displaying the articles as Cards.

    Loading/Error States: Show a CircularProgressIndicator while fetching, and display readable error messages using a SnackBar or Text widget if something fails (e.g., "City not found").

6. Testing Requirements

    Integration Test: Include a Flutter Integration Test using the integration_test package.

    The test must:

        Pump the app.

        Enter a city name into the text field (testing the manual fallback path to avoid emulator GPS permission issues).

        Tap the search button.

        Verify that loading state appears, and eventually, that the list of articles populates.

7. Instructions for Code Generation (Prompt to Copilot)

Based on the specification above, please generate the following files step-by-step:

    pubspec.yaml: The dependencies block including http, geolocator, flutter_riverpod, and url_launcher.

    lib/api/api_service.dart: The API models and fetching logic. Include React/TS translation comments (e.g., explaining jsonDecode and factory constructors).

    lib/state/app_state.dart: The immutable state class and Riverpod Notifier. Explain how this maps to Zustand/Redux.

    lib/main.dart: The UI layer. Ensure accessibility (Semantics) is implemented and show how ref.watch maps to React Hooks.

    integration_test/app_test.dart: A clean, fully commented integration test covering the manual search flow.