import SwiftUI

@Observable
final class REPLViewModel {
    var code = ""
    var history: [REPLEntry] = []

    private let engine = V8Engine()

    func run() {
        let input = code
        guard !input.isEmpty else { return }
        code = ""

        let result = engine.eval(input)
        history.append(REPLEntry(
            input: input,
            output: result.output,
            isError: !result.success
        ))
    }

    func clear() {
        history.removeAll()
        engine.reset()
    }
}

struct REPLEntry: Identifiable {
    let id = UUID()
    let input: String
    let output: String
    let isError: Bool
}
