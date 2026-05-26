import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    listContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("지출 내역")
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HistoryViewModel(
                    repository: SwiftDataExpenseRepository(modelContext: modelContext)
                )
            }
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder
    private func listContent(_ vm: HistoryViewModel) -> some View {
        List {
            ForEach(vm.groupedByDate) { group in
                Section(group.dateLabel) {
                    ForEach(group.items) { item in
                        ExpenseRow(item: item)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { i in
                            Task { await vm.delete(group.items[i]) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(
            text: Binding(get: { vm.searchQuery }, set: { vm.searchQuery = $0 }),
            prompt: "물건 이름으로 검색"
        )
        .refreshable { await vm.load() }
        .overlay {
            if vm.filteredItems.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    vm.searchQuery.isEmpty ? "기록 없음" : "검색 결과 없음",
                    systemImage: vm.searchQuery.isEmpty ? "bag" : "magnifyingglass",
                    description: Text(
                        vm.searchQuery.isEmpty
                        ? "카메라로 물건을 찍으면 여기에 기록됩니다"
                        : "'\(vm.searchQuery)'에 해당하는 항목이 없습니다"
                    )
                )
            }
        }
        .alert("오류", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(vm.error?.localizedDescription ?? "")
        }
    }
}

// MARK: - Row

private struct ExpenseRow: View {
    let item: ExpenseItem
    private let storage = ImageStorageService()
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            // 누끼 썸네일
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .frame(width: 54, height: 54)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(item.category.emoji)
                        .font(.title2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.category.emoji)
                    Text(item.category.displayName)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Text(item.amount, format: .currency(code: "KRW"))
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
        .task {
            guard let path = item.imagePath else { return }
            thumbnail = try? storage.load(from: path)
        }
    }
}
