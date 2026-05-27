# 📸 Snap Budget

> 사진 한 장으로 끝나는 가계부 — AI가 물건을 인식하고, 같은 걸 다시 사면 자동으로 채워줍니다.

[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)](https://developer.apple.com/xcode/swiftui/)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM%20%2B%20Repository-green)](#아키텍처)

> ⚠️ 이 브랜치(`ios-app`)는 iOS Swift 프로젝트입니다.
> 같은 레포 `main` 브랜치의 웹 프로젝트와 **별개**의 코드베이스입니다.

---

## 💡 핵심 컨셉

기존 가계부는 **숫자 위주**라 입력이 귀찮고 무엇을 샀는지 기억하기 어렵습니다.
Snap Budget은 **사진 위주**입니다:

1. 📸 산 물건을 찍는다
2. 🤖 AI가 배경을 제거하고(누끼) 물건을 인식한다
3. 💰 가격만 입력하면 끝
4. ✨ 같은 물건을 다시 찍으면 **이름·가격·카테고리가 자동**으로 채워진다 → 1탭 저장

→ 가계부를 "기록"이 아니라 **"시각적 컬렉션"** 으로 만들어 무의식적 소비를 의식하게 합니다.

---

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| 📷 **자동 배경 제거 (누끼)** | Vision의 `VNGenerateForegroundInstanceMaskRequest` 사용. 여러 객체가 있어도 면적 60% + 중심도 40% 점수로 가장 주요한 1개만 자동 선택 |
| 🧠 **반복 구매 자동 인식** | 768차원 이미지 임베딩으로 과거 구매와 유사도 비교 → "전에 산 라떼와 같음" 자동 감지 |
| ⚡ **1탭 저장** | 매칭 성공 시 모든 필드 자동 채움. 사용자는 확인 버튼만 누르면 됨 |
| 🏷️ **AI 카테고리 분류** | `VNClassifyImageRequest`로 식품/쇼핑/전자기기 등 9개 카테고리 자동 추론 |
| 🖼️ **시각적 대시보드** | 이번 달 지출 + 카테고리별 막대 + 최근 구매 그리드(누끼 썸네일) |
| 📂 **HEIC 압축 저장** | PNG 대비 **용량 85% 절감** + 알파 채널 보존 + 512px 썸네일 자동 캐싱 |
| ☁️ **완전 로컬** | 모든 AI 처리가 기기에서 — 사진/데이터가 외부로 안 나감 (네트워크 불필요) |

---

## 🏗️ 아키텍처

**MVVM + Repository Pattern**, 의존성 최소화 (서드파티 라이브러리 0개)

```
┌─────────────────────────────────────────────────┐
│  Views (SwiftUI)                                 │
│  ├─ ContentView (TabView: 내역 · 촬영 · 요약)     │
│  ├─ CaptureView, ExpenseEntryView                │
│  └─ DashboardView, HistoryView                   │
└────────────────────┬────────────────────────────┘
                     │ @Observable ViewModels
┌────────────────────▼────────────────────────────┐
│  ViewModels (MVVM)                               │
│  ├─ CaptureViewModel                             │
│  ├─ ExpenseEntryViewModel                        │
│  ├─ DashboardViewModel, HistoryViewModel         │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  Services (도메인 로직, actor 격리)                │
│  ├─ CameraService (AVFoundation)                 │
│  ├─ ImageAnalysisService (Vision 누끼+분류+임베딩) │
│  ├─ ImageStorageService (HEIC 저장/캐싱)          │
│  └─ PurchaseMatcher (임베딩 유사도 매칭)           │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  Repository (데이터 추상화)                        │
│  ├─ ExpenseRepository (protocol)                 │
│  └─ SwiftDataExpenseRepository (impl)            │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  Persistence                                     │
│  ├─ SwiftData (메타데이터)                         │
│  └─ FileSystem (HEIC 이미지)                      │
└─────────────────────────────────────────────────┘
```

---

## 🛠️ 기술 스택

| 영역 | 사용 기술 | 비고 |
|------|----------|------|
| **UI** | SwiftUI + NavigationStack | iOS 16+ 기반 |
| **언어** | Swift 5.9+ | Strict Concurrency (Swift 6 준비) |
| **상태 관리** | `@Observable` (Observation 프레임워크) | iOS 17+ |
| **데이터** | SwiftData + 파일시스템 | 메타데이터는 DB, 이미지는 파일 |
| **카메라** | AVFoundation | 직접 세션 관리 |
| **AI / Vision** | Vision 프레임워크 (Apple Native) | 외부 API 없음 |
| **이미지 포맷** | HEIC (알파 채널 지원) | PNG 대비 ~85% 절감 |
| **동시성** | Swift Concurrency (async/await, actor) | 메인 스레드 보호 |

### 외부 라이브러리

**없음.** Apple 네이티브 프레임워크만 사용 — App Store 심사 리스크 최소화, 앱 크기 최소화, 장기 유지보수 용이.

---

## 🤖 AI 매칭 시스템 (핵심 차별점)

### 작동 방식

```
📸 새 사진
   │
   ▼
🔍 Vision: VNGenerateImageFeaturePrintRequest
   → 768차원 이미지 임베딩 추출 (~3KB)
   │
   ▼
🗄️ 과거 구매 DB에서 임베딩 비교
   → computeDistance(_:to:) 로 유클리드 거리 계산
   │
   ┌──────────────┴──────────────┐
   ▼                             ▼
거리 ≤ 18.0 (보수적 임계값)    거리 > 18.0
   │                             │
   ▼                             ▼
✅ 같은 물건 판단                ❌ 처음 보는 물건
   • 이름/금액/카테고리 자동 채움    • AI가 분류한 대분류만 채움
   • 유사도 % 표시 (예: 92%)       • 사용자가 정확한 이름·가격 입력
   • 버튼: "바로 저장" (1탭)        • 버튼: "저장"
```

### 임계값 18.0인 이유

VNFeaturePrint 거리 기준:

| 상황 | 거리값 |
|------|-------|
| 동일 사진 | ~0 |
| 같은 물건, 조명만 다름 | 5~12 |
| 같은 물건, 각도도 다름 | 10~20 |
| 비슷한 물건 (다른 브랜드) | 20~35 |
| 전혀 다른 물건 | 35+ |

→ **18.0은 약간 보수적**. 잘못된 매칭(false positive)은 사용자에게 짜증나니까 안전한 쪽으로 설정. 약간 놓치는 경우(false negative)는 그냥 재입력하면 됨.

조정은 `PurchaseMatcher.defaultThreshold` 한 줄 수정으로 가능.

### 비용

**0원.** 모든 AI 처리가 디바이스 로컬에서 수행됩니다. 향후 cloud LLM(Claude Haiku 등)을 추가하면 구체적 상품명("스벅 톨 라떼") 인식까지 가능하나, 현재는 일반 분류 + 반복 매칭만으로도 사용성 충분.

---

## 📁 프로젝트 구조

```
Snapbudget/
├── App/                              # 앱 진입점
│   ├── SnapBudgetApp.swift            # @main, ModelContainer, 고아 파일 정리
│   ├── AppState.swift                 # 전역 상태 (선택 탭, 모달)
│   └── ContentView.swift              # TabView (내역·촬영·요약)
│
├── Core/                             # 도메인 로직 (UI 독립)
│   ├── Models/
│   │   ├── ExpenseItem.swift          # @Model SwiftData 엔티티
│   │   └── ExpenseCategory.swift      # 9개 카테고리 enum
│   ├── Repositories/
│   │   ├── ExpenseRepository.swift              # 프로토콜
│   │   └── SwiftDataExpenseRepository.swift     # 구현체
│   └── Services/
│       ├── CameraService.swift        # AVFoundation 세션 관리
│       ├── ImageAnalysisService.swift # Vision: 누끼 + 분류 + 임베딩
│       ├── ImageStorageService.swift  # HEIC 저장, 썸네일, 고아 정리 (actor)
│       └── PurchaseMatcher.swift      # 임베딩 거리 비교
│
├── Features/                         # 화면별 MVVM
│   ├── Capture/                       # 카메라 촬영
│   │   ├── CaptureView.swift
│   │   ├── CaptureViewModel.swift
│   │   └── Components/CameraPreviewView.swift
│   ├── ExpenseEntry/                  # 지출 입력 (자동 채움 배너 포함)
│   ├── Dashboard/                     # 이번 달 요약
│   └── History/                       # 지출 내역 리스트
│
└── Shared/                           # 공용 유틸
    ├── Extensions/
    │   ├── UIImage+HEIC.swift         # HEIC 인코딩 + 다운샘플링
    │   ├── View+Extensions.swift
    │   └── Decimal+Extensions.swift
    └── Components/
        └── SubjectImageView.swift     # 누끼 썸네일 (메모리 캐시 포함)
```

---

## 🚀 시작하기

### 요구사항

- **macOS 14+** (Xcode 16 필요)
- **Xcode 16+** (SwiftData, `@Observable`, iOS 17 API)
- **iOS 17.0+** 시뮬레이터 또는 실기기 (Vision 신규 API 사용)
- 카메라 테스트는 **실기기 필수** (시뮬레이터에 카메라 없음)
- Apple Developer 계정 (자동 코드 사이닝)

### 빌드 방법

```bash
git clone https://github.com/minddoi/Hi-Dong.git
cd Hi-Dong
git checkout ios-app
open Snapbudget.xcodeproj
```

Xcode에서:

1. **TARGETS → Signing & Capabilities**
   - `DEVELOPMENT_TEAM`을 본인 Apple Developer Team ID로 변경
   - `PRODUCT_BUNDLE_IDENTIFIER`도 본인 ID로 (예: `com.yourname.snapbudget`)
2. Destination을 **실기기**(추천) 또는 **iOS 17+ 시뮬레이터**로 선택
3. `⌘ + R` 실행

### 권한 (Info.plist 자동 생성)

- `NSCameraUsageDescription` — "구매한 물건을 촬영해 가계부에 기록합니다"

---

## 🗃️ 데이터 모델

### ExpenseItem (SwiftData @Model)

```swift
@Model
final class ExpenseItem {
    var id: UUID
    var name: String                      // 물건명
    var amount: Decimal                   // 금액 (KRW)
    var category: ExpenseCategory         // 9개 enum
    var date: Date

    var imageFilename: String?            // 풀사이즈 HEIC 파일명 (절대경로 X)
    var thumbnailFilename: String?        // 썸네일 HEIC 파일명
    var imageEmbedding: Data?             // 768차원 Vision FeaturePrint
    var notes: String?
}
```

### 디스크 저장 구조

```
Documents/SnapBudget/Images/
├── full/
│   └── subject_<uuid>.heic              # ~480KB (알파 보존)
└── thumb/
    └── subject_<uuid>_thumb.heic        # ~15KB (512px 정사각)
```

### 왜 절대경로 대신 파일명만 저장하나?

iOS 앱 컨테이너 경로는 다음 상황에서 **UUID가 바뀝니다**:
- 앱 재설치
- iCloud 백업 복원
- 기기 마이그레이션

절대경로를 저장했다면 위 상황 후 모든 이미지가 깨집니다. 파일명만 저장하고 런타임에 현재 Documents 경로와 조합하면 안전합니다.

---

## 📊 데이터 흐름 예시

### 새 물건 처음 구매

```
1. CaptureView가 카메라 세션 시작
2. 사용자가 셔터 → CameraService가 UIImage 반환
3. ImageAnalysisService.analyze(image) 병렬 실행:
   - removeBackground() → 누끼 UIImage
   - classifyImage()    → "cup" + 0.78 confidence + .food
   - extractFeaturePrint() → 768차원 임베딩 Data
4. PurchaseMatcher가 과거 구매 임베딩과 비교 → 매칭 없음
5. ExpenseEntryView 시트 표시
   - 이름: "컵" (자동)
   - 금액: 빈칸 (사용자 입력)
6. 사용자가 가격 4500 입력 → "저장"
7. ImageStorageService.save(): full + thumbnail HEIC 동시 저장
8. SwiftData에 ExpenseItem 저장 (임베딩 포함)
```

### 같은 물건 다시 구매

```
1~4번까지 동일 — 단, 4번에서 매칭 성공 (거리 8.45)
5. ExpenseEntryView 시트 표시
   - ✨ 배너: "전에 산 물건 같아요 · 컵 · ₩4,500 · 3일 전 · 92%"
   - 이름: "컵" (이전 데이터 자동)
   - 금액: "4500" (이전 데이터 자동)
   - 카테고리: .food (자동)
6. 사용자가 "바로 저장" 한 번 탭
7. 새 ExpenseItem 저장
```

---

## 🗺️ 로드맵

### ✅ 완료
- [x] 카메라 촬영 + AVFoundation 세션 관리
- [x] Vision 기반 배경 제거 (멀티 객체 → 주요 객체 1개 자동 선택)
- [x] HEIC 압축 저장 + 썸네일 자동 생성
- [x] 메모리 캐시 (NSCache 200개 / 50MB)
- [x] 임베딩 기반 반복 구매 자동 매칭
- [x] 1탭 저장 UX
- [x] 대시보드 + 카테고리 차트 + 최근 구매 그리드
- [x] 지출 내역 (날짜별 그룹, 검색, 삭제)
- [x] 고아 이미지 파일 자동 정리

### 📅 예정
- [ ] Cloud Vision LLM 통합 (Claude Haiku 4.7) — 구체적 상품명 인식 ("스벅 톨 라떼")
- [ ] 카테고리 → 다중 태그 시스템 (자유 태그 + 사용자 정의)
- [ ] AI 학습 — 사용자 수정 패턴을 다음 인식에 반영
- [ ] 예산 목표 (카테고리별 월 예산 + 초과 알림)
- [ ] iCloud 동기화 (CloudKit)
- [ ] CSV 내보내기 / 다른 가계부 앱 마이그레이션
- [ ] 위젯, Shortcuts 액션 지원

---

## 🤝 기여

이슈/PR 환영. 큰 변경은 이슈로 먼저 논의 부탁드립니다.

### 커밋 메시지 규칙

```
<type>: <description>
```

타입: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

---

## 📄 라이선스

미정 (현재 개인 프로젝트). 추후 정식 배포 시 명시 예정.
