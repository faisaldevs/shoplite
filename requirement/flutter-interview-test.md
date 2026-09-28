# Flutter Developer Technical Interview (Mid-Level)

Version 1.0

---

## Table of Contents

1. [Overview](#1-overview)
2. [General Rules](#2-general-rules)
3. [Environment Setup](#3-environment-setup)
4. [Round 1: ShopLite Live Coding Task](#4-round-1-shoplite-live-coding-task)
5. [Round 2: Code Review and Bug Hunt](#5-round-2-code-review-and-bug-hunt)
6. [Round 3: Dart Fundamentals](#6-round-3-dart-fundamentals)
7. [Round 4: UI and Animation](#7-round-4-ui-and-animation)
8. [Round 5: Technical Discussion](#8-round-5-technical-discussion)
9. [Evaluation Criteria](#9-evaluation-criteria)
10. [Submission Checklist](#10-submission-checklist)

---

## 1. Overview

This interview evaluates a mid-level Flutter developer across architecture, state management, networking, local persistence, authentication, media handling, testing, UI skills, Dart fundamentals, and team collaboration.

### Skills Assessed

| Area | Topics |
|---|---|
| Clean Architecture | Separation of data, domain, and presentation layers; dependency direction |
| BLoC | Events, states, streams, event transformers, basic testing |
| Drift | CRUD operations, relationships, migrations |
| Retrofit + Dio | API services, error handling, interceptors |
| Authentication | Token storage, refresh flow, `flutter_secure_storage` |
| Media Management | Image caching, offline file storage |
| Team Collaboration | Git workflow, code review, documentation, linting |
| General Flutter | Rendering, performance, animations, theming, responsive layout |
| Dart | Async, streams, generics, extensions, testing |

### Interview Structure

| Round | Title | Duration |
|---|---|---|
| 1 | ShopLite: Offline-Capable Product Catalog | 3 hours 30 minutes |
| 2 | Code Review and Bug Hunt | 25 minutes |
| 3 | Dart Fundamentals | 20 minutes |
| 4 | UI and Animation | 40 minutes |
| 5 | Technical Discussion | 30 minutes |
| | Total | About 5 hours 25 minutes (plus breaks) |

A 10 to 15 minute break is recommended between Round 1 and the remaining rounds.

---

## 2. General Rules

### Allowed

- Official documentation (flutter.dev, dart.dev, package docs)
- pub.dev
- IDE features (autocomplete, refactoring tools, snippets built into the IDE)
- Asking the interviewer clarifying questions at any time

### Not Allowed

- AI coding assistants of any kind
- Copying code from personal templates, previous projects, or repositories
- Copying complete solutions from tutorials or articles

### Expectations

- Start from an empty project created with `flutter create`.
- Think out loud and explain decisions as you make them.
- Commit to git throughout the session. The commit history is part of the evaluation.
- If you cannot finish everything, prioritize working, clean core features over partially completed extras.
- If you make a trade-off due to time, state it and document it in the README.

---

## 3. Environment Setup

### Requirements

- Flutter SDK (latest stable)
- An Android emulator, iOS simulator, or physical device
- Git
- Internet access (the API is public)

### Project Creation

```bash
flutter create shoplite
cd shoplite
git init
git add .
git commit -m "chore: initial flutter project"
```

### Required Technologies

The following are mandatory for Round 1. Specific package versions are your choice.

| Purpose | Required |
|---|---|
| State management | `flutter_bloc` (Bloc with events, not Cubit) |
| HTTP client | `dio` |
| API layer | `retrofit` + `retrofit_generator` |
| Local database | `drift` |
| Secure token storage | `flutter_secure_storage` |
| Dependency injection | `get_it` or any approach you can justify |
| Testing | `flutter_test`, plus any mocking library (`mocktail` recommended) and `bloc_test` |
| Linting | Any lint package (for example `very_good_analysis` or `flutter_lints`) |

You may add other packages (for example `equatable`, `fpdart`, `cached_network_image`, `path_provider`) but must be able to justify each one.

---

## 4. Round 1: ShopLite Live Coding Task

**Duration:** 3 hours 30 minutes

### 4.1 Product Description

ShopLite is a product catalog app for logged-in users. It must continue to work without an internet connection by using locally cached data, and users can save product images for offline viewing and keep a list of favorites.

### 4.2 API Reference

**Base URL:** `https://dummyjson.com`

**Test credentials:**

| Username | Password |
|---|---|
| `emilys` | `emilyspass` |

Any user from `https://dummyjson.com/users` can also be used.

#### Authentication Endpoints

| Method | Endpoint | Body | Description |
|---|---|---|---|
| POST | `/auth/login` | `{ "username", "password", "expiresInMins" }` | Returns user data plus `accessToken` and `refreshToken` |
| POST | `/auth/refresh` | `{ "refreshToken", "expiresInMins" }` | Returns a new `accessToken` and `refreshToken` |
| GET | `/auth/me` | none | Returns the current user (requires token) |

Authenticated requests use the header:

```
Authorization: Bearer <accessToken>
```

#### Product Endpoints

Any resource can be made protected by prefixing it with `/auth`. **All product requests in this task must use the protected versions.**

| Method | Endpoint | Description |
|---|---|---|
| GET | `/auth/products?limit=20&skip=0` | Paginated product list |
| GET | `/auth/products/search?q={query}` | Search products |
| GET | `/auth/products/categories` | List categories |
| GET | `/auth/products/{id}` | Single product |

#### Product List Response Shape

```json
{
  "products": [
    {
      "id": 1,
      "title": "Essence Mascara Lash Princess",
      "description": "...",
      "category": "beauty",
      "price": 9.99,
      "rating": 4.94,
      "thumbnail": "https://...",
      "images": ["https://...", "https://..."]
    }
  ],
  "total": 194,
  "skip": 0,
  "limit": 20
}
```

Only map the fields you need. Unused fields may be ignored.

### 4.3 Requirements

Each requirement lists acceptance criteria. A requirement is considered complete only when all of its criteria are met.

#### R1. Authentication

**Description:** Users log in with username and password. Sessions persist across app restarts and are refreshed automatically.

**Acceptance criteria:**

1. The login screen validates that both fields are non-empty before submitting.
2. The login screen shows a loading state while the request is in progress and disables the submit button.
3. Wrong credentials show a readable error message (not a raw exception).
4. Login is performed with `expiresInMins: 1` so the refresh flow can be verified during review.
5. Tokens are stored using `flutter_secure_storage`.
6. On app restart, a user with a stored session goes directly to the product list.
7. When a request returns 401, the app refreshes the token and retries the original request automatically.
8. When several requests fail with 401 at the same time, only **one** refresh request is sent.
9. If the refresh request fails, the session is cleared and the user is returned to the login screen with a message explaining that the session expired.
10. A logout action clears tokens and all user-specific cached data, then returns to the login screen.

#### R2. Product List

**Description:** A paginated, searchable list of products.

**Acceptance criteria:**

1. Products load 20 at a time. Scrolling near the bottom loads the next page.
2. A loading indicator appears at the bottom of the list while the next page loads.
3. No further requests are made once all products have been loaded.
4. Pull to refresh reloads the first page.
5. Search input is debounced by 400 ms.
6. An older search response must never overwrite results for a newer query.
7. Clearing the search returns to the normal paginated list.
8. Loading, empty, error, and content states are visually distinct.
9. The error state offers a retry action.

#### R3. Offline Support and Favorites (Drift)

**Description:** Products are cached locally. The database is the single source of truth for the UI. Users can manage a local list of favorites.

**Acceptance criteria:**

1. Fetched products are stored in a Drift database.
2. The product list UI reads from the database (for example using a Drift `watch()` stream), not directly from API responses.
3. With no internet connection, the app displays cached products.
4. A visible banner indicates when the app is offline or showing cached data.
5. A `favorites` table stores favorites locally and references products through a foreign key. Be ready to justify the relationship type you chose.
6. Favorites support full CRUD: add, remove, list, and clear all.
7. Deleting a product row does not leave orphaned favorite rows.
8. A Favorites screen shows the list reactively (it updates immediately when a favorite is added or removed elsewhere).

#### R4. Product Details and Media

**Description:** A detail screen with image handling for both online and offline use.

**Acceptance criteria:**

1. The detail screen shows title, price, rating, description, and an image gallery.
2. Network images are cached on disk (they do not re-download on every visit).
3. A "Save for offline" button downloads all images of the product to app storage.
4. Local file paths of saved images are stored in the database.
5. When offline, saved images load from local files.
6. A "Remove offline copy" button deletes the files from storage and updates the database.
7. Download progress or at least a loading state is shown during saving.

#### R5. Testing

**Description:** A minimum set of automated tests.

**Acceptance criteria:**

1. **Bloc test:** the product list bloc, covering at least one success and one failure scenario.
2. **Repository test:** when the API call fails, the repository falls back to cached data.
3. **Drift test:** uses an in-memory database and verifies at least one CRUD operation and the relationship behavior from R3.7.
4. **Bonus:** a test for the auth interceptor or auth repository (for example, a single refresh for concurrent 401 responses).
5. All tests pass with `flutter test`.

#### R6. Collaboration and Delivery

**Description:** The project should be ready for another developer to pick up.

**Acceptance criteria:**

1. Commits are frequent and meaningful, using a consistent convention (for example `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
2. `analysis_options.yaml` includes a lint package, and `flutter analyze` reports zero issues at the end.
3. A `README.md` includes:
   - Setup and run instructions
   - The code generation command
   - A short architecture overview (layers and data flow)
   - Decisions and trade-offs made during the session
   - Known limitations and what you would do with more time

### 4.4 Change Request (Mid-Session)

At approximately the **2 hour** mark, the interviewer will deliver the following change request. You will have **30 minutes** to complete it.

> The product team wants users to add a personal note to each favorite. Users who already have favorites saved must keep them after updating the app.

**Acceptance criteria:**

1. A nullable `note` column is added to the favorites table.
2. The schema version is increased, and an upgrade step adds the column without losing existing data.
3. The UI allows adding and editing a note on a favorite.
4. **Bonus:** a test verifying the migration preserves existing favorites.

This change request evaluates how you handle evolving requirements and database migrations during active development.

### 4.5 Timeline and Checkpoints

The interviewer checks in at each checkpoint. Checkpoints are guidance, not hard deadlines, but significant delays will be discussed.

| Time | Focus | Expected State |
|---|---|---|
| 0:00 to 0:30 | Setup | Folders, dependencies, DI, lint rules, first commits |
| 0:30 to 1:20 | R1 Authentication | Login, secure storage, interceptor with refresh |
| 1:20 to 2:10 | R2 and R3 | Product list, pagination, search, Drift cache |
| 2:10 to 2:40 | Change request | Migration and note feature |
| 2:40 to 3:10 | R3 and R4 | Favorites screen, detail screen, offline media |
| 3:10 to 3:30 | R5 and R6 | Tests, README, final commits |
| 3:30 | Demo | 5-minute walkthrough of the app and code |

### 4.6 Demo Walkthrough

At the end of Round 1, present a 5-minute walkthrough covering:

1. Login, then wait for token expiry and show that requests still succeed.
2. Pagination and search.
3. Offline mode (turn off network) showing cached products and saved images.
4. Favorites with notes.
5. A brief tour of the folder structure and one feature from UI to API.

---

## 5. Round 2: Code Review and Bug Hunt

**Duration:** 25 minutes

### Task

Review the following two files as if they were submitted by a teammate in a pull request.

For each issue:

1. Identify the problem.
2. Explain its impact (crash, memory leak, incorrect behavior, performance, maintainability).
3. Propose a fix.

Finally, write corrected versions of both files.

There are **at least 8 issues** across the two files.

### File 1: `search_page.dart`

```dart
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  List<Product> results = [];
  Timer? timer;

  @override
  Widget build(BuildContext context) {
    final bloc = ProductBloc(ApiService());
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: (q) {
              timer = Timer(const Duration(milliseconds: 500), () async {
                final data = await ApiService().search(q);
                setState(() => results = data);
              });
            },
          ),
          ListView(
            children: results.map((p) => ProductTile(p)).toList(),
          ),
        ],
      ),
    );
  }
}
```

### File 2: `cart_bloc.dart`

```dart
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(CartState(items: [])) {
    on<AddItem>((event, emit) {
      state.items.add(event.product);
      emit(state);
    });

    on<LoadCart>((event, emit) {
      repository.getCart().then((items) {
        emit(CartState(items: items));
      });
    });
  }
}
```

### Evaluation

- Number of real issues identified
- Quality of explanations (the "why", not only the "what")
- Correctness and cleanliness of the fixed code
- Tone of review comments (constructive, as you would write to a teammate)

---

## 6. Round 3: Dart Fundamentals

**Duration:** 20 minutes

**Environment:** Pure Dart (no Flutter). A `dart create` console project or a test file is fine.

### Task 3.1: Retry with Exponential Backoff

Implement:

```dart
Future<T> retry<T>(
  Future<T> Function() task, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  bool Function(Object error)? retryIf,
});
```

**Requirements:**

1. Calls `task` up to `maxAttempts` times.
2. The delay doubles after each failed attempt (500 ms, 1000 ms, 2000 ms, and so on).
3. If `retryIf` is provided, only errors for which it returns `true` are retried. Other errors are rethrown immediately.
4. If all attempts fail, the last error is rethrown with its original stack trace.

### Task 3.2: Stream Debounce Extension

Implement without using `rxdart`:

```dart
extension DebounceX<T> on Stream<T> {
  Stream<T> debounce(Duration duration);
}
```

**Requirements:**

1. Emits a value only after `duration` has passed without a new value.
2. When the source stream closes, any pending value is emitted before closing.
3. Cancelling the subscription cancels the internal timer and the source subscription.
4. Errors from the source are forwarded.

### Task 3.3: Tests

Write unit tests for both functions. Using fake time (for example `fake_async`) is preferred over real delays.

---

## 7. Round 4: UI and Animation

**Duration:** 40 minutes

**Environment:** A new screen in the ShopLite project or a new Flutter project. Use 10 hardcoded products (no API calls).

### Requirements

1. **Responsive grid:** 2 columns on phones, 3 on small tablets, 4 or more on wide screens. Use `LayoutBuilder` or constraints, not device-type checks.
2. **Product card:** image, title, price, and a favorite button.
3. **Implicit animation:** toggling the favorite button animates (for example scale or color change).
4. **Hero transition:** tapping a card opens a detail page with a `Hero` animation on the image.
5. **Theming:** light and dark themes using `ThemeData` and `ColorScheme`. No hardcoded colors inside widgets.
6. **Performance:** use builder constructors and `const` constructors where appropriate. Be prepared to explain why each matters.

### Bonus

- A shimmer-style loading placeholder implemented without a third-party package.

---

## 8. Round 5: Technical Discussion

**Duration:** 30 minutes

The interviewer selects approximately 8 questions based on performance in earlier rounds. Answers should include reasoning and, where possible, real examples.

### Flutter Internals

1. Explain the widget, element, and render object trees. What happens when `setState` is called?
2. When are `Key`s needed? Describe a real bug that a `Key` fixes.
3. What does `BuildContext` represent? Why must `mounted` be checked after an `await`?

### State Management

4. Bloc versus Cubit: when would you choose each? What are event transformers used for?

### Performance

5. How would you run heavy JSON parsing without freezing the UI? Compare `compute` and `Isolate.run`.
6. How do you identify and fix jank? Which DevTools features do you use?
7. What steps reduce app size?

### Architecture and Data

8. Offline-first versus online-first: what are the trade-offs? How would you handle sync conflicts?
9. Where should tokens be stored and why not `SharedPreferences`? What are the platform differences in secure storage?

### Team and Delivery

10. How would you structure a project so five developers can work in parallel with minimal conflicts?
11. What should a CI pipeline run on every pull request?
12. How would you set up dev, staging, and production flavors with different base URLs?

### Troubleshooting

13. How would you handle deep links in an app that requires authentication?
14. Walk through how you would debug a crash reported only on some Android devices.

---

## 9. Evaluation Criteria

### 9.1 Round 1 Scoring (100 points)

| Area | Points | What Is Evaluated |
|---|---|---|
| Architecture and layer separation | 20 | Domain has no Flutter, Dio, Drift, or JSON dependencies; repositories behind interfaces; mapping between models and entities; consistent feature-first structure |
| Auth and interceptor | 20 | Secure storage, auto-login, single refresh for concurrent 401s, correct retry, session expiry handling, logout cleanup |
| Drift | 15 | Table design, relationships with foreign keys, reactive queries, CRUD, migration from the change request |
| BLoC design | 15 | Clear events and states, correct use of streams, debounce and pagination logic, no state mutation, proper disposal |
| Offline and media | 10 | Database as source of truth, offline banner, image caching, file download and cleanup |
| Tests | 10 | Required tests present, meaningful assertions, tests pass |
| Code quality and collaboration | 10 | Commit history, zero analyzer issues, README quality, naming, communication during the session |

### 9.2 Performance Levels per Area

| Level | Description |
|---|---|
| Strong | Complete, correct, and clean. Edge cases handled. Decisions explained clearly. |
| Acceptable | Works for the main path. Minor gaps in edge cases or structure. |
| Weak | Partially working or tightly coupled. Significant correctness issues. |
| Missing | Not attempted or not functional. |

### 9.3 Other Rounds

| Round | Evaluation Focus |
|---|---|
| Round 2 | Issues found, explanation depth, fix quality, review tone |
| Round 3 | Correctness, edge cases (cancellation, stack traces), test quality |
| Round 4 | Responsiveness, animation smoothness, theming discipline, performance awareness |
| Round 5 | Depth of understanding, practical experience, clarity of explanation |

### 9.4 Overall Decision Guidance

| Result | Criteria |
|---|---|
| Strong hire | Round 1 score of 80 or more, and strong performance in at least three other rounds |
| Hire | Round 1 score of 65 or more with R1 (Authentication) fully working, and acceptable performance in the other rounds |
| Borderline | Round 1 score between 50 and 64, or a weak result in two or more other rounds |
| No hire | Round 1 score below 50, or authentication not functional |

### 9.5 Red Flags

- State mutated directly inside a bloc
- Business logic inside widgets
- Tokens stored in plain storage such as `SharedPreferences`
- Domain layer importing data-layer packages
- A single commit containing all work
- Unable to explain code that was written during the session

---

## 10. Submission Checklist

Complete this checklist before the Round 1 demo.

### Functionality

- [ ] Login works and shows validation, loading, and error states
- [ ] Session persists after app restart
- [ ] Token refresh works after the 1-minute expiry
- [ ] Only one refresh request is sent for concurrent 401 responses
- [ ] Session expiry returns the user to login with a message
- [ ] Logout clears tokens and user data
- [ ] Pagination loads more products and stops at the end
- [ ] Search is debounced and never shows stale results
- [ ] Pull to refresh works
- [ ] Cached products display when offline, with an offline banner
- [ ] Favorites CRUD works and updates reactively
- [ ] Deleting a product does not leave orphaned favorites
- [ ] Favorite notes work, and existing favorites survive the migration
- [ ] Network images are cached
- [ ] Save for offline downloads images and stores paths
- [ ] Remove offline copy deletes files and updates the database

### Quality

- [ ] `flutter analyze` reports zero issues
- [ ] `flutter test` passes
- [ ] Commits follow a consistent convention
- [ ] README is complete

### Code Generation

- [ ] Generated files are up to date:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

*End of document.*
