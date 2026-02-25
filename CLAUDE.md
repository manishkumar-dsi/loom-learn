# CLAUDE.md — loom-learn

Guidance for AI assistants working on **loom-learn**: a Flutter-based ChatGPT-style learning application with linked virtual-page exploration.

---

## What Is Loom Learn?

**Loom Learn** is a mobile-first (iOS/Android) chat application backed by the OpenAI API. Its defining feature is **linked exploration**: when reading an AI response, the user can select any word or phrase to spawn a contextual "virtual page" — a child conversation that dives into that topic. Virtual pages can nest arbitrarily deep, forming a knowledge graph. All data, including the API key, stays on the device.

Key differentiators from ChatGPT:
1. **Linked exploration** — text selection creates navigable child pages.
2. **Conversation graph** — conversations are trees of nodes, not linear threads.
3. **Client-only storage** — no backend; API key in OS secure enclave; conversations in SharedPreferences as JSON.
4. **Refined dark UI** — violet/cyan palette, richer typography and animations.

---

## Repository Structure

```
loom-learn/
├── CLAUDE.md                          # This file
├── pubspec.yaml                       # Flutter project config & dependencies
├── assets/                            # Static assets (images, fonts if added)
├── test/
│   └── widget_test.dart               # Unit tests for data models
└── lib/
    ├── main.dart                      # Entry point — bootstraps SharedPreferences, ProviderScope
    ├── app.dart                       # LoomLearnApp (MaterialApp, theme, HomeScreen)
    ├── core/
    │   ├── theme/
    │   │   ├── app_colors.dart        # Full colour palette (AppColors constants)
    │   │   └── app_theme.dart         # ThemeData (dark theme)
    │   ├── services/
    │   │   ├── openai_service.dart    # OpenAI Chat Completions API (SSE streaming)
    │   │   └── storage_service.dart   # SharedPreferences + FlutterSecureStorage wrapper
    │   └── utils/
    │       └── id_generator.dart      # UUID v4 factory
    ├── data/
    │   ├── models/
    │   │   ├── message.dart           # Message (role, content, links, isStreaming)
    │   │   ├── text_link.dart         # TextLink (trigger text → child node id)
    │   │   ├── conversation_node.dart # ConversationNode (a single "page")
    │   │   └── conversation.dart      # Conversation (root + node graph)
    │   └── repositories/
    │       └── conversation_repository.dart  # All CRUD + virtual-page creation
    ├── presentation/
    │   ├── providers/
    │   │   ├── storage_provider.dart         # SharedPreferences + StorageService providers
    │   │   ├── api_key_provider.dart         # SettingsState / SettingsNotifier
    │   │   ├── conversations_provider.dart   # ConversationsState / ConversationsNotifier
    │   │   └── chat_provider.dart            # NodeChatState / ChatNotifier (per conversation)
    │   ├── screens/
    │   │   ├── home_screen.dart       # Adaptive root layout (drawer vs split-view)
    │   │   ├── chat_screen.dart       # Chat view + virtual-page stack overlay
    │   │   └── settings_screen.dart   # API key + model selection
    │   └── widgets/
    │       ├── app_sidebar.dart        # Conversation list sidebar
    │       ├── message_bubble.dart     # User / assistant message rendering
    │       ├── linked_text_widget.dart # SelectableText.rich with tappable link spans
    │       ├── chat_input.dart         # Compose bar (multi-line, Enter-to-send)
    │       ├── virtual_page_panel.dart # Sliding exploration page overlay
    │       ├── breadcrumb_bar.dart     # Navigation breadcrumb for virtual pages
    │       └── typing_indicator.dart   # Animated 3-dot loader
```

---

## Architecture

### Data Model — Conversation Graph

```
Conversation
  ├── id, title, rootNodeId
  └── nodes: Map<String, ConversationNode>
        ├── root node  (parentNodeId = null)
        └── child nodes (parentNodeId = parent, triggerText = selected text)

ConversationNode
  ├── id, conversationId, parentNodeId, triggerText, title
  └── messages: List<Message>
        └── Message
              ├── id, role (user|assistant|system), content, timestamp
              └── links: List<TextLink>
                    └── TextLink  (triggerText, startOffset, endOffset, childNodeId)
```

- The graph is a **tree** (DAG where each node has at most one parent).
- All nodes live inside the `Conversation.nodes` map; references use string IDs.
- `TextLink`s are embedded in assistant `Message`s; they mark which spans of text have been explored and link to child nodes.

### State Management — Riverpod

| Provider | Type | Responsibility |
|---|---|---|
| `sharedPreferencesProvider` | `Provider<SharedPreferences>` | Overridden at startup in `main.dart` |
| `storageServiceProvider` | `Provider<StorageService>` | Wraps SharedPreferences + SecureStorage |
| `conversationRepositoryProvider` | `Provider<ConversationRepository>` | All conversation CRUD |
| `settingsProvider` | `StateNotifierProvider<SettingsNotifier, SettingsState>` | API key, model selection |
| `conversationsProvider` | `StateNotifierProvider<ConversationsNotifier, ConversationsState>` | List of conversations, active conversation |
| `chatProvider(conversationId)` | `StateNotifierProvider.family<ChatNotifier, NodeChatState, String>` | Per-conversation chat state, streaming, virtual-page navigation stack |

### Virtual Page Navigation

`ChatNotifier` owns a `List<String> nodeStack` inside `NodeChatState`. This acts as a navigation stack:

```
nodeStack = ['root']              → showing main chat
nodeStack = ['root', 'child1']   → VirtualPagePanel for child1 layered on top
nodeStack = ['root', 'child1', 'grandchild']  → double-deep exploration
```

`ChatScreen` renders a `Stack`:
1. Root chat messages (always present underneath).
2. If `nodeStack.length > 1`: dimmed backdrop + `VirtualPagePanel` slides in from right via `SlideTransition`.

### OpenAI Streaming (SSE)

`OpenAIService.streamChat` returns a `Stream<String>` of text deltas. It uses `http.Client.send()` with a streamed response, parses the `data: {...}` SSE lines, extracts `choices[0].delta.content`, and yields each token. The `ChatNotifier` accumulates tokens and calls `updateMessageInNode` on every delta so the UI rebuilds incrementally.

### Persistence

| Data | Storage | Location |
|---|---|---|
| API key | `FlutterSecureStorage` (OS keychain/keystore) | Encrypted on-device |
| Model selection | `SharedPreferences` | `selected_model` key |
| Conversations | `SharedPreferences` | `conversations` key (JSON array) |

Everything is client-side. No backend. No analytics.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.7 (required for `contextMenuBuilder` API)
- Dart SDK ≥ 3.1
- An [OpenAI API key](https://platform.openai.com/account/api-keys)

### Setup

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run on a connected device or emulator
flutter run

# 3. On first launch, tap the banner or go to Settings → add your OpenAI key
```

### Platform notes

- **Android**: `flutter_secure_storage` uses `EncryptedSharedPreferences`.
- **iOS**: uses the iOS Keychain.
- **Web**: `flutter_secure_storage` falls back to `localStorage` on web — not recommended for sensitive keys.

---

## Development Workflow

### Branching

- Default branch: `main`
- AI-assisted work: `claude/<description>-<session-id>`
- Feature work: `feature/<short-description>`
- Never push to `main` without a PR.

### Commits

- Imperative, scoped: `Add streaming indicator`, `Fix TextLink offset on markdown messages`
- Reference issues: `Fix #12: breadcrumb renders wrong node title`

### Running Tests

```bash
flutter test
```

Tests live in `test/`. Current coverage: data model serialisation / deserialisation.

### Linting

```bash
flutter analyze
```

Config: `analysis_options.yaml` (uses `flutter_lints`). All warnings should be resolved before committing.

---

## Commands

```bash
flutter pub get          # Install / update dependencies
flutter run              # Run on connected device (debug)
flutter run --release    # Production build on device
flutter build apk        # Android APK
flutter build ios        # iOS (requires macOS + Xcode)
flutter test             # All tests
flutter analyze          # Static analysis
```

---

## Code Style & Conventions

- Dart style guide + `flutter_lints` enforced by `flutter analyze`.
- `const` constructors everywhere possible.
- Prefer `final` over `var`.
- No `dynamic` except in JSON parsing.
- Widget files: one public widget per file, private helpers below it in the same file.
- Provider files: one `StateNotifier` + its `StateNotifierProvider` per file.
- All magic strings → named constants (see `app_colors.dart`, `storage_service.dart`).
- Never store secrets in source code or `SharedPreferences` in plaintext — always use `FlutterSecureStorage`.

---

## Key Conventions for AI Assistants

1. **Read before editing.** Always read a file before modifying it.
2. **Minimal changes.** Only change what the task requires. Do not refactor adjacent code.
3. **Maintain the graph model.** All conversation mutations go through `ConversationRepository`. Do not mutate models directly in UI code.
4. **Streaming correctness.** When appending tokens, always call `updateMessageInNode` (not `addMessageToNode`) for the in-progress message.
5. **No secrets in code.** API key via `FlutterSecureStorage` only.
6. **Run `flutter analyze` after changes** to catch type errors and lints before committing.
7. **Run `flutter test` after changes** to ensure model serialisation is intact.
8. **No speculative features.** Implement only what is explicitly requested.
9. **Security first.** Never log or print the API key. Validate user input at widget boundaries.
10. **Commit on feature branches.** Use the `claude/` branch for AI work.
11. **Update this file** when adding new dependencies, screens, or architectural patterns.

---

## Architecture Decision Log

| Decision | Rationale |
|---|---|
| Riverpod (StateNotifier) over Bloc | Less boilerplate for a solo-dev project; no code generation required |
| SharedPreferences + JSON over SQLite/Hive | Simplest path, no codegen, sufficient for conversation-size data |
| FlutterSecureStorage for API key | OS-level encryption; key never stored in plaintext |
| `Stack` + `SlideTransition` for virtual pages | Full control over animation and z-order; avoids Navigator stack complications |
| `SelectableText.rich` with `TapGestureRecognizer` for links | Best Flutter 3.7+ approach for mixed selectable + tappable spans |
| SSE streaming via `http.Client.send` | Official `http` package is sufficient; avoids adding an OpenAI-specific dependency |
| `family` provider for chat | Clean isolation per conversation; avoids global streaming state collisions |

---

## Environment Variables

No environment variables are used. The OpenAI API key is entered at runtime in Settings and stored in the OS secure enclave.

Do **not** add `.env` files, hardcode keys, or commit any credentials.

---

## CI/CD

Not yet configured. Recommended next steps:
- GitHub Actions: `flutter test && flutter analyze` on every PR.
- Fastlane for iOS/Android release distribution.

---

*Last updated: 2026-02-25*
