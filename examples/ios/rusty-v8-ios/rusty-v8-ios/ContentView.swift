import SwiftUI

struct ContentView: View {
    @State private var vm = REPLViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    Text("V8 JavaScript REPL")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        vm.clear()
                    }
                    .font(.caption)
                    .disabled(vm.history.isEmpty)
                }
                .padding()

                Divider()

                // Output: 2/3
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(vm.history) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("> \(entry.input)")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text(entry.output)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(entry.isError ? .red : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: vm.history.count) {
                        if let last = vm.history.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .frame(height: geo.size.height * 2 / 3)

                Divider()

                // Input: 1/3
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { run() }) {
                            Image(systemName: "play.fill")
                                .padding(8)
                        }
                        .disabled(vm.code.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    TextEditor(text: $vm.code)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func run() {
        vm.run()
        isInputFocused = true
    }
}

#Preview {
    ContentView()
}
