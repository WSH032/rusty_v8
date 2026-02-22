# rusty_v8 iOS Example

A SwiftUI REPL app that embeds the V8 JavaScript engine on iOS via a Rust static library.

## Architecture

```
v8-bridge/          Rust staticlib crate — C FFI wrapper around v8
rusty-v8-ios/       Xcode project (SwiftUI app + Swift tests)
  pre-build.sh      Xcode Run Script Phase — builds the Rust crate and copies libv8_bridge.a
```

`v8-bridge` exposes C functions (`v8_bridge_init`, `v8_bridge_engine_new`, `v8_bridge_engine_eval`, etc.) via cbindgen-generated header. Swift calls them through a bridging header.

The Xcode project links the Rust library via `OTHER_LDFLAGS = -lv8_bridge` and `LIBRARY_SEARCH_PATHS = $(BUILT_PRODUCTS_DIR)`. Swift calls C FFI functions through a bridging header that imports the cbindgen-generated `v8-bridge.h`.

## Prerequisites

- Xcode 16+
- Rust toolchain with iOS targets:
  ```
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```

## Build & Run

Open `rusty-v8-ios.xcodeproj` in Xcode, and press Cmd+R. The Run Script Phase (`pre-build.sh`) automatically invokes `cargo build` for the correct target.

## Test

**Xcode:** Cmd+U in Xcode runs the Swift tests (`rusty-v8-iosTests`).

**CLI:**
```bash
xcodebuild test \
  -project examples/ios/rusty-v8-ios/rusty-v8-ios.xcodeproj \
  -scheme rusty-v8-ios \
  -destination "platform=iOS Simulator,name=iPhone 16,arch=arm64" \
  -only-testing:rusty-v8-iosTests \
  ENABLE_USER_SCRIPT_SANDBOXING=NO
```

## Feature Flags

Pass Cargo feature flags via the `RUSTY_V8_CARGO_FEATURE_FLAGS` environment variable:

```bash
RUSTY_V8_CARGO_FEATURE_FLAGS="--features ios_v8_enable_webassembly,ios_cppgc_enable_caged_heap" \
  xcodebuild build ...
```
