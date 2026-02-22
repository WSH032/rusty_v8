#!/bin/bash
# Pre-build script for rusty-v8 iOS bridge.
# Called by Xcode's "Build Rust Library" Run Script Phase.
#
# Required env vars (set by Xcode):
#   SRCROOT, PLATFORM_NAME, ARCHS, CONFIGURATION, BUILT_PRODUCTS_DIR
#
# Optional env vars:
#   RUSTY_V8_CARGO_FEATURE_FLAGS  – extra cargo flags (e.g. --features ...)

set -e
export PATH="$HOME/.cargo/bin:$PATH"
cd "$SRCROOT/../../.."  # repo root

if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
  if [ "$ARCHS" = "x86_64" ]; then
    RUST_TARGET="x86_64-apple-ios"
  else
    RUST_TARGET="aarch64-apple-ios-sim"
  fi
else
  RUST_TARGET="aarch64-apple-ios"
fi

if [ "$CONFIGURATION" = "Release" ]; then
  CARGO_VARIANT_FLAG="--release"
  LIB_DIR="release"
else
  CARGO_VARIANT_FLAG=""
  LIB_DIR="debug"
fi

export V8_FROM_SOURCE=1
cargo build -p v8-ios-bridge -vv --target "$RUST_TARGET" $CARGO_VARIANT_FLAG $RUSTY_V8_CARGO_FEATURE_FLAGS
mkdir -p "$BUILT_PRODUCTS_DIR"
cp "target/$RUST_TARGET/$LIB_DIR/libv8_bridge.a" "$BUILT_PRODUCTS_DIR/"
