# CLAUDE.md — loom-learn

Guidance for AI assistants working on **loom-learn**: a Flutter-based reading-first learning app backed by the OpenAI API, with Kindle-inspired UI/UX and linked virtual-page exploration.

---

## What Is Loom Learn?

**Loom Learn** is a mobile-first (iOS/Android) chat application backed by the OpenAI API. Its defining feature is **linked exploration**: when reading an AI response, the user can select any word or phrase to spawn a contextual "virtual page" — a child conversation that dives deeper into that topic. Virtual pages can nest arbitrarily deep, forming a knowledge graph. All data stays on the device.

**Design philosophy:** The reading experience is primary. Every UI decision borrows from Kindle — typography is king, distractions are removed during reading, and information is revealed progressively.

---

## Repository Structure

```
loom-learn/
├── CLAUDE.md
├── pubspec.yaml
├── assets/
├── test/widget_test.dart
└── lib/
    ├── main.dart                          # Bootstrap: SharedPreferences, ProviderScope
    ├── app.dart                           # ConsumerWidget; watches readingThemeProvider
    │                                      # → MaterialApp re-themes on every mode change
    ├── core/
    │   ├── theme/
    │   │   ├── app_colors.dart            # Legacy static dark-mode constants (avoid in new code)
    │   │   ├── app_theme.dart             # Legacy ThemeData (superseded by ReadingThemeData)
    │   │   └── reading_theme.dart         # ★ ReadingThemeData: 4 presets (white/sepia/dark/night)
    │   ├── services/
    │   │   ├── openai_service.dart        # SSE streaming via http.Client
    │   │   └── storage_service.dart       # SharedPreferences + FlutterSecureStorage
    │   └── utils/id_generator.dart        # UUID v4
    ├── data/
    │   ├── models/
    │   │   ├── reading_settings.dart      # ★ ReadingSettings: theme, font, spacing, margins
    │   │   ├── message.dart               # Message (role, content, links, isStreaming)
    │   │   ├── text_link.dart             # TextLink → child node
    │   │   ├── conversation_node.dart     # ConversationNode (a reading page)
    │   │   └── conversation.dart          # Conversation (root + node graph)
    │   └── repositories/
    │       └── conversation_repository.dart  # All CRUD + virtual-page creation
    └── presentation/
        ├── providers/
        │   ├── storage_provider.dart              # SharedPreferences injection
        │   ├── api_key_provider.dart              # SettingsState (API key + model)
        │   ├── conversations_provider.dart        # Conversation list + active id
        │   ├── chat_provider.dart                 # Per-conversation state + nodeStack
        │   └── reading_settings_provider.dart     # ★ ReadingSettingsNotifier + readingThemeProvider
        ├── screens/
        │   ├── home_screen.dart           # Adaptive layout (drawer / sidebar)
        │   ├── chat_screen.dart           # ★ Kindle reading view + Aa button + bottom sheet
        │   └── settings_screen.dart       # API key + model (fully theme-aware)
        └── widgets/
            ├── app_sidebar.dart                   # Conversation list (theme-aware)
            ├── theme_aware_chat_input.dart         # ★ Input bar using ReadingThemeData
            ├── reading_toolbar_sheet.dart          # ★ "Aa" bottom sheet (font/theme/spacing)
            ├── exploration_bottom_sheet.dart       # ★ Kindle X-Ray virtual page bottom sheet
            ├── reading_layout/
            │   ├── reading_message_view.dart       # ★ Top-level reading layout widget
            │   ├── reading_response_view.dart      # ★ Prose AI response + custom context menu
            │   └── question_card.dart              # ★ User question styled as annotation card
            │
            │   ── Legacy / still used for linked text in older paths ──
            ├── linked_text_widget.dart
            ├── message_bubble.dart
            ├── virtual_page_panel.dart
            ├── breadcrumb_bar.dart
            ├── chat_input.dart
            └── typing_indicator.dart
```

---

## Kindle-Inspired UX Architecture

### Design Principles (adapted from Kindle)

| Kindle Principle | Loom Learn Implementation |
|---|---|
| Typography is king | Configurable font (sans/serif/mono), size (13–24px), line height, margins |
| 4 reading modes | White, Sepia, Dark, Night — full `ReadingThemeData` per mode |
| X-Ray for deep reading | Text selection → "Ask AI" → `DraggableScrollableSheet` slides up |
| Progressive disclosure | "Aa" icon in header opens settings only when needed |
| Distraction-free layout | AI responses rendered as continuous prose, not chat bubbles |
| Comfortable reading width | `ConstrainedBox(maxWidth: 860)` prevents over-wide lines |
| Visual depth cues | Level dots badge (●●●) shows exploration nesting depth |
| Context strip | "Exploring: 'triggerText'" banner in every virtual page |

### Reading Theme System

```
ReadingThemeMode (enum)
  white  → ReadingThemeData.white   (bg #FAFAFA, text #1C1C1E, accent iOS purple)
  sepia  → ReadingThemeData.sepia   (bg #F8EDD9, text #3D2B1F, accent warm brown)
  dark   → ReadingThemeData.dark    (bg #131313, text #E8E8E8, accent violet)
  night  → ReadingThemeData.night   (bg #000000, text #B8B8B8, OLED black)

ReadingThemeData
  ├── 25 semantic color properties (background, surface, text*, accent*, link*, etc.)
  ├── questionCardBg/Border  — user question card styling
  ├── sectionDivider         — ··· ornamental divider between Q&A pairs
  ├── exploredHighlight      — tint on text that has been linked to a virtual page
  ├── isDark                 — boolean for icon/overlay decisions
  ├── systemOverlayStyle     — SystemUiOverlayStyle for status bar
  └── toMaterialTheme()      — bridges to MaterialApp ThemeData
```

The `readingThemeProvider` (derived Riverpod `Provider`) maps `ReadingSettings.theme` → `ReadingThemeData`. `app.dart` watches it and calls `readingTheme.toMaterialTheme()` on every change, so the entire app re-themes without restart.

### Reading Layout (vs chat bubbles)

**Old**: User bubble (right) + Assistant bubble (left) with avatar
**New**: Kindle document layout

```
[QuestionCard]        ← compact card, "You" label + question text
[ReadingResponseView] ← full-width prose (MarkdownBody inside SelectionArea)
  [ExplorationChips]  ← cyan chips listing existing virtual page links
[SectionDivider]      ← ornamental ··· divider
[QuestionCard]
[ReadingResponseView]
...
```

Prose rendering uses `MarkdownBody` inside a `SelectionArea` with a custom `contextMenuBuilder` that overlays a `_KindleContextMenu` widget — a floating panel with **Ask AI** (primary, accent-tinted) and **Copy** (secondary).

### Typography Controls ("Aa" Panel)

`showReadingToolbar(context)` opens a `showModalBottomSheet` containing `_ReadingToolbarSheet`:

| Control | Widget | Range / Options |
|---|---|---|
| Font Size | `SliderTheme` + `Slider` | 13–24 px (11 divisions) |
| Typeface | 3-column font preview grid | Sans / Serif (Georgia) / Mono |
| Line Spacing | 3-segment toggle | Compact 1.45 / Normal 1.70 / Wide 2.05 |
| Margins | 3-segment toggle | Narrow 16 / Normal 24 / Wide 40 px |
| Theme | 4 colored "Aa" swatches | White / Sepia / Dark / Night |

All changes persist immediately to `SharedPreferences` via `ReadingSettingsNotifier`.

### Virtual Page = Kindle X-Ray Bottom Sheet

**Old**: `VirtualPagePanel` — full-screen slide from right
**New**: `ExplorationBottomSheet` — `DraggableScrollableSheet` from bottom

```
Snap points:  48 % height (peek)  →  100 % height (full screen)
Drag handle:  36×4 px pill at top
Header:       ↓ back | 📖 title | ●●● Level N badge
Context strip: 💬 Exploring: "triggerText" (italic, cyan)
Body:          ReadingMessageView (same reading layout as main chat)
Input:         ThemeAwareChatInput (same theme, compact rounded)
```

When `chatState.nodeStack.length > 1`, `ChatScreen` renders:
1. A `Container(color: black×0.3)` scrim behind the sheet
2. `ExplorationBottomSheet` on top (managed by `DraggableScrollableController`)

Navigation back closes the sheet by calling `chatNotifier.popVirtualPage()`.

---

## Data Model — Conversation Graph

```
Conversation
  ├── id, title, rootNodeId, createdAt, updatedAt
  └── nodes: Map<String, ConversationNode>
        ├── root node (parentNodeId = null)
        └── child nodes (parentNodeId = parent.id, triggerText = selection)
              └── messages: List<Message>
                    └── links: List<TextLink>
                          └── TextLink.childNodeId → child ConversationNode
```

All mutations go through `ConversationRepository`. The repository is the single source of truth.

---

## State Management — Riverpod

| Provider | Description |
|---|---|
| `sharedPreferencesProvider` | Overridden at startup in `main.dart` |
| `storageServiceProvider` | Wraps SharedPreferences + SecureStorage |
| `conversationRepositoryProvider` | All conversation CRUD |
| `settingsProvider` | API key, model selection |
| `readingSettingsProvider` | Font, theme, spacing, margin — persisted to prefs |
| `readingThemeProvider` | Derived: `ReadingThemeData` for current theme mode |
| `conversationsProvider` | List + active conversation |
| `chatProvider(conversationId)` | Per-conversation: messages, nodeStack, streaming |

---

## Getting Started

### Prerequisites
- Flutter ≥ 3.7 (required for `contextMenuBuilder` + `SelectionArea.contextMenuBuilder`)
- Dart ≥ 3.1
- An OpenAI API key

### Setup

```bash
flutter pub get
flutter run
# First launch → tap the top banner or open Settings → enter your API key
```

---

## Development Workflow

### Branching
- AI work: `claude/<description>-<session-id>`
- Never push to `main` without a PR

### Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Debug on device
flutter run --release    # Release build
flutter build apk        # Android APK
flutter build ios        # iOS (macOS + Xcode required)
flutter test             # Model serialisation tests
flutter analyze          # Static analysis (must pass before commit)
```

---

## Key Conventions for AI Assistants

1. **Use `ReadingThemeData` for all UI colors** — never use `AppColors.*` in new or modified widgets. The `AppColors` class is legacy; new code accesses theme via `ref.watch(readingThemeProvider)`.
2. **Read before editing.** Never guess at file contents.
3. **Minimal changes.** Only change what the task requires.
4. **Mutations through the repository.** Never mutate models directly in UI code.
5. **Streaming correctness.** Use `updateMessageInNode` (not `addMessageToNode`) for the in-progress streaming message.
6. **No secrets in code.** API key via `FlutterSecureStorage` only.
7. **Run `flutter analyze` after changes** — the CI/CD pipeline will enforce this.
8. **Run `flutter test` after changes** to verify model serialisation.
9. **Commit on `claude/` feature branches.**
10. **Update this file** when adding new features, dependencies, or architectural patterns.

---

## Architecture Decision Log

| Decision | Rationale |
|---|---|
| `ReadingThemeData` separate from `ThemeData` | More control; `ThemeData` can be derived on-demand via `toMaterialTheme()` |
| `DraggableScrollableSheet` for virtual pages | Kindle X-Ray feel; dual snap heights (peek/full); native iOS feel |
| `SelectionArea` + custom `contextMenuBuilder` | Markdown rendered by `MarkdownBody` (not `SelectableText`); `SelectionArea` wraps it |
| `ReadingSettingsProvider` separate from `SettingsProvider` | Reading prefs change frequently (live preview); API settings rarely change |
| `ReadingMessageView` replaces `MessageBubble` | Prose layout more natural for long-form AI answers; matches Kindle document style |
| Font size via `MarkdownStyleSheet` | All heading/body/code sizes derived from `settings.fontSize` as a multiplier |
| `ThemeAwareChatInput` separate from `ChatInput` | Input appears in both main chat and virtual page sheet; theme injection via constructor is cleaner than reading a provider inside the widget |

---

## Environment Variables

No environment variables. API key entered at runtime in Settings → stored in OS secure enclave.

Never commit `.env` files or secrets.

---

## CI/CD

Not yet configured. Recommended pipeline:
- `flutter test && flutter analyze` on every PR
- Fastlane for iOS/Android release distribution

---

*Last updated: 2026-02-25 (Kindle-inspired UI/UX redesign)*
