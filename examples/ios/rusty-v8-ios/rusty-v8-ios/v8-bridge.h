#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Result of a JavaScript evaluation, returned to the C/Swift caller.
 */
typedef struct V8EvalResult {
  /**
   * `true` if the evaluation succeeded, `false` if it threw an error.
   */
  bool success;
  /**
   * A null-terminated UTF-8 string containing the result (on success)
   * or the error message (on failure). Must be freed with
   * `v8_bridge_result_free`.
   */
  char *data;
} V8EvalResult;

/**
 * Initialize the V8 platform. Must be called once before any other function.
 */
void v8_bridge_init(void);

/**
 * Create a new V8 engine instance with its own isolate and context.
 * Returns an opaque pointer. Must be freed with `v8_bridge_engine_free`.
 */
void *v8_bridge_engine_new(void);

/**
 * Evaluate a JavaScript string in the given engine's context.
 * State persists across calls (variables, functions, etc.).
 *
 * # Safety
 *
 * `engine` must be a valid pointer from `v8_bridge_engine_new`.
 * `code` must be a valid null-terminated UTF-8 string.
 */
struct V8EvalResult v8_bridge_engine_eval(void *engine, const char *code);

/**
 * Free a `V8EvalResult`'s data string.
 *
 * # Safety
 *
 * `data` must be a pointer previously returned in a `V8EvalResult`, or null.
 */
void v8_bridge_result_free(char *data);

/**
 * Destroy a V8 engine instance and release its resources.
 *
 * # Safety
 *
 * `engine` must be a valid pointer from `v8_bridge_engine_new`, or null.
 */
void v8_bridge_engine_free(void *engine);
