import SwiftUI
import SwiftData

struct ExpenseEntryView: View {
    @Environment(\.modelContext) private var modelContext

    let analysisResult: ImageAnalysisResult
    let onSaved: () -> Void   // 저장 완료 후 호출 (sheet dismiss + CaptureView dismiss)

    @State private var viewModel: ExpenseEntryViewModel?
    @FocusState private var focusedField: Field?

    private enum Field { case name, amount, notes }

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let repo = SwiftDataExpenseRepository(modelContext: modelContext)
            viewModel = ExpenseEntryViewModel(analysisResult: analysisResult, repository: repo)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private func formContent(_ vm: ExpenseEntryViewModel) -> some View {
        NavigationStack {
            Form {
                // ── 누끼 이미지 미리보기 ──────────────────
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: vm.subjectImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // ── 물건 정보 ─────────────────────────────
                Section("물건 정보") {
                    HStack {
                        TextField("물건 이름", text: Binding(
                            get: { vm.name },
                            set: { vm.name = $0 }
                        ))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }

                        // 인식 신뢰도가 낮으면 힌트 표시
                        if vm.recognitionConfidence < 0.5 {
                            Image(systemName: "pencil.circle")
                                .foregroundStyle(.orange)
                                .accessibilityLabel("이름을 확인해 주세요")
                        }
                    }

                    HStack(spacing: 4) {
                        Text("₩")
                            .foregroundStyle(.secondary)
                        TextField("금액", text: Binding(
                            get: { vm.amountText },
                            set: { vm.amountText = $0 }
                        ))
                        .focused($focusedField, equals: .amount)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                    }

                    Picker("카테고리", selection: Binding(
                        get: { vm.category },
                        set: { vm.category = $0 }
                    )) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Text("\(cat.emoji) \(cat.displayName)").tag(cat)
                        }
                    }
                }

                // ── 메모 (선택) ───────────────────────────
                Section {
                    TextField("메모 (선택)", text: Binding(
                        get: { vm.notes },
                        set: { vm.notes = $0 }
                    ), axis: .vertical)
                    .focused($focusedField, equals: .notes)
                    .lineLimit(2...4)
                } header: {
                    Text("메모")
                }
            }
            .navigationTitle("지출 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onSaved() } // onSaved로 통합 처리
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSaving {
                        ProgressView()
                    } else {
                        Button("저장") {
                            Task {
                                do {
                                    try await vm.save()
                                    onSaved()
                                } catch {
                                    vm.saveError = error
                                }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!vm.isValid)
                    }
                }
            }
            .alert("저장 실패", isPresented: Binding(
                get: { vm.saveError != nil },
                set: { if !$0 { vm.saveError = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(vm.saveError?.localizedDescription ?? "")
            }
        }
    }
}
