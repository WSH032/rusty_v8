import Testing
import rusty_v8_ios

struct V8EngineTests {

    @Test func evalPersistentContext() {
        let engine = V8Engine()
        _ = engine.eval("var x = 10")
        let result = engine.eval("x * 3")
        #expect(result.success)
        #expect(result.output == "30")
    }

    @Test func evalSyntaxError() {
        let engine = V8Engine()
        let result = engine.eval("}{")
        #expect(!result.success)
    }

    @Test func evalRuntimeError() {
        let engine = V8Engine()
        let result = engine.eval("undefinedVar.property")
        #expect(!result.success)
    }

    @Test func evalResetContext() {
        let engine = V8Engine()
        _ = engine.eval("var y = 99")
        engine.reset()
        let result = engine.eval("y")
        #expect(!result.success)
    }
}
