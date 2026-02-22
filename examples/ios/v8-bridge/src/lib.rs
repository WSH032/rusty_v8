use std::ffi::{CStr, CString, c_char, c_void};

/// Result of a JavaScript evaluation, returned to the C/Swift caller.
#[repr(C)]
pub struct V8EvalResult {
  /// `true` if the evaluation succeeded, `false` if it threw an error.
  pub success: bool,
  /// A null-terminated UTF-8 string containing the result (on success)
  /// or the error message (on failure). Must be freed with
  /// `v8_bridge_result_free`.
  pub data: *mut c_char,
}

/// An opaque handle to a V8 JavaScript engine instance.
///
/// Each instance owns its own `Isolate` and `Context`, allowing
/// multiple evaluations to share state.
struct V8Engine {
  isolate: v8::OwnedIsolate,
  context: v8::Global<v8::Context>,
}

impl V8Engine {
  fn new() -> Self {
    let mut isolate = v8::Isolate::new(v8::CreateParams::default());
    let context = {
      v8::scope!(let scope, &mut isolate);
      let context = v8::Context::new(scope, Default::default());
      v8::Global::new(scope, context)
    };
    V8Engine { isolate, context }
  }

  fn eval(&mut self, code: &str) -> Result<String, String> {
    v8::scope!(let scope, &mut self.isolate);
    let context = v8::Local::new(scope, &self.context);
    let mut scope = v8::ContextScope::new(scope, context);
    v8::tc_scope!(let tc, &mut scope);

    let Some(code) = v8::String::new(tc, code) else {
      return Err("Failed to create V8 string".to_string());
    };

    let Some(script) = v8::Script::compile(tc, code, None) else {
      let err = tc
        .stack_trace()
        .or_else(|| tc.exception())
        .map(|v| v.to_rust_string_lossy(tc))
        .unwrap_or_else(|| "Compile error".to_string());
      return Err(err);
    };

    match script.run(tc) {
      Some(result) => {
        let s = result
          .to_string(tc)
          .map(|s| s.to_rust_string_lossy(tc))
          .unwrap_or_else(|| "undefined".to_string());
        Ok(s)
      }
      None => {
        let err = tc
          .stack_trace()
          .or_else(|| tc.exception())
          .map(|v| v.to_rust_string_lossy(tc))
          .unwrap_or_else(|| "Runtime error".to_string());
        Err(err)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// C FFI
// ---------------------------------------------------------------------------

/// Initialize the V8 platform. Must be called once before any other function.
#[unsafe(no_mangle)]
pub extern "C" fn v8_bridge_init() {
  let platform = v8::new_default_platform(0, false).make_shared();
  v8::V8::initialize_platform(platform);
  v8::V8::initialize();
}

/// Create a new V8 engine instance with its own isolate and context.
/// Returns an opaque pointer. Must be freed with `v8_bridge_engine_free`.
#[unsafe(no_mangle)]
pub extern "C" fn v8_bridge_engine_new() -> *mut c_void {
  let engine = Box::new(V8Engine::new());
  Box::into_raw(engine) as *mut c_void
}

/// Evaluate a JavaScript string in the given engine's context.
/// State persists across calls (variables, functions, etc.).
///
/// # Safety
///
/// `engine` must be a valid pointer from `v8_bridge_engine_new`.
/// `code` must be a valid null-terminated UTF-8 string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn v8_bridge_engine_eval(
  engine: *mut c_void,
  code: *const c_char,
) -> V8EvalResult {
  if engine.is_null() || code.is_null() {
    return V8EvalResult {
      success: false,
      data: CString::new("null pointer").unwrap().into_raw(),
    };
  }

  let engine = unsafe { &mut *(engine as *mut V8Engine) };
  let code = unsafe { CStr::from_ptr(code) };
  let code = match code.to_str() {
    Ok(s) => s,
    Err(e) => {
      return V8EvalResult {
        success: false,
        data: CString::new(format!("Invalid UTF-8: {e}"))
          .unwrap()
          .into_raw(),
      };
    }
  };

  match engine.eval(code) {
    Ok(result) => V8EvalResult {
      success: true,
      data: CString::new(result).unwrap_or_default().into_raw(),
    },
    Err(err) => V8EvalResult {
      success: false,
      data: CString::new(err).unwrap_or_default().into_raw(),
    },
  }
}

/// Free a `V8EvalResult`'s data string.
///
/// # Safety
///
/// `data` must be a pointer previously returned in a `V8EvalResult`, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn v8_bridge_result_free(data: *mut c_char) {
  if !data.is_null() {
    let _ = unsafe { CString::from_raw(data) };
  }
}

/// Destroy a V8 engine instance and release its resources.
///
/// # Safety
///
/// `engine` must be a valid pointer from `v8_bridge_engine_new`, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn v8_bridge_engine_free(engine: *mut c_void) {
  if !engine.is_null() {
    let _ = unsafe { Box::from_raw(engine as *mut V8Engine) };
  }
}
