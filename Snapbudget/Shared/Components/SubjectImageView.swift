import SwiftUI

/// 누끼 이미지를 비동기 로드해 표시하는 공용 컴포넌트
/// 이미지가 없거나 로드 실패 시 카테고리 이모지를 폴백으로 사용
struct SubjectImageView: View {
    let item: ExpenseItem
    let storage: ImageStorageService

    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))

            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Text(item.category.emoji)
                    .font(.largeTitle)
            }
        }
        .task(id: item.imagePath) {
            guard let path = item.imagePath else { return }
            loadedImage = try? storage.load(from: path)
        }
    }
}
