import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("이번 달 요약")
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(
                    repository: SwiftDataExpenseRepository(modelContext: modelContext)
                )
            }
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder
    private func content(_ vm: DashboardViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                TotalAmountCard(amount: vm.totalThisMonth)

                if !vm.categoryBreakdown.isEmpty {
                    CategoryBreakdownCard(shares: vm.categoryBreakdown)
                }

                if !vm.recentItems.isEmpty {
                    RecentPurchasesGrid(items: vm.recentItems)
                }

                if vm.items.isEmpty && !vm.isLoading {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100) // 플로팅 버튼 여백
        }
        .refreshable { await vm.load() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "기록 없음",
            systemImage: "camera.circle",
            description: Text("카메라 버튼으로 구매한 물건을\n찍어 기록해 보세요")
        )
        .padding(.top, 40)
    }
}

// MARK: - Total Amount Card

private struct TotalAmountCard: View {
    let amount: Decimal

    var body: some View {
        VStack(spacing: 6) {
            Text("이번 달 지출")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "KRW"))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Category Breakdown Card

private struct CategoryBreakdownCard: View {
    let shares: [CategoryShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("카테고리별 지출")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(shares) { share in
                CategoryBarRow(share: share)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct CategoryBarRow: View {
    let share: CategoryShare

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(share.category.emoji + " " + share.category.displayName)
                    .font(.subheadline)
                Spacer()
                Text(share.amount, format: .currency(code: "KRW"))
                    .font(.subheadline.weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * share.ratio)
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - Recent Purchases Grid

private struct RecentPurchasesGrid: View {
    let items: [ExpenseItem]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let storage = ImageStorageService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 구매")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    SubjectThumbnail(item: item, storage: storage)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SubjectThumbnail: View {
    let item: ExpenseItem
    let storage: ImageStorageService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Text(item.category.emoji)
                    .font(.title)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            guard let path = item.imagePath else { return }
            image = try? storage.load(from: path)
        }
    }
}
