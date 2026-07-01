# Jezsic — Architecture & Developer Guidelines

**IMPORTANT INSTRUCTION FOR ALL DEVELOPERS AND AI AGENTS: READ THIS BEFORE UNDERTAKING ANY TASK.**

This project uses a hybrid architecture combining Flutter/Dart and Rust via FFI (`flutter_rust_bridge` v2). We enforce a strict boundary between UI and business logic.

---

## 🏗️ Core Architectural Rules

### 1. UI is Handled by Flutter (Dart)
* All screens, layouts, widgets, navigation routing, theme configurations, animations, and input fields are implemented in Dart.
* **No business logic should be written in Dart.** Dart should only capture user events, pass arguments to Rust, and render the output.

### 2. Logic, Algorithms, & Functions are Handled by Rust
* All computations, search algorithms, sorting rules, file operations (sanitization, path construction, renaming, deleting), data mutations, and serialization/deserialization (JSON) must live in Rust.
* Code should be organized cleanly under the `rust/src/api/` directory inside dedicated domain modules:
  * `models.rs` — FFI-compatible data models.
  * `scanner.rs` — Filesystem scanning and lofty audio metadata parsing.
  * `search.rs` — Search and sort filters.
  * `playlist.rs` — JSON serialization/deserialization and play counts.
  * `playback.rs` — Next/previous song transition index calculations.
  * `file_ops.rs` — Native file renaming, deletions, and playlist syncing.
  * `format.rs` — Text, duration, and file size formatting utilities.

### 3. FFI Boundaries & Calling Conventions
* We use `flutter_rust_bridge` to link Rust and Dart. 
* Run `flutter_rust_bridge_codegen generate` in the root folder to update bindings after modifying any Rust API files.
* **Synchronous FFI Call Mapping (`sync`)**:
  * Pure utilities, calculations, formatters, and serialization helpers must be annotated with `#[flutter_rust_bridge::frb(sync)]` in Rust so Dart can call them synchronously without `Future` queues or `async/await` boilerplate.
* **Asynchronous Calls**:
  * File I/O operations (renaming, deleting) and recursive filesystem scans must run asynchronously (without the `sync` flag) to prevent blocking the Dart UI thread.

### 4. Platform API Layer (Dart Proxy)
* Actions requiring direct OS bindings must be handled in Dart (Audio playback via `just_audio`/`audio_service`, Bluetooth connection events via `flutter_blue_plus`, notifications, and SharedPreferences storage).
* **State Syncing**: The Dart wrapper must immediately sync any background OS events (such as media track shifts) with Rust-backed state variables (e.g. syncing `currentlyPlaying` by listening to `mediaItem` stream state updates).
