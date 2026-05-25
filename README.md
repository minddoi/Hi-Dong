# Monent Expense MVP

React + Vite + TypeScript로 만든 모바일 웹 사진 기반 가계부 MVP입니다.

## 주요 기능

- 모바일 카메라 촬영 또는 사진 업로드
- 브라우저에서 `@imgly/background-removal`로 배경 제거
- 누끼 실패 시 원본 이미지로 저장
- 물건명, 가격, 카테고리 입력
- 오늘 지출만 localStorage에 저장 및 표시
- 지출 카드 삭제

## 실행 방법

```bash
npm create vite@latest
npm install
npm install @imgly/background-removal
npm run dev
```

이 프로젝트 폴더에서는 이미 필요한 파일이 구성되어 있으므로 아래 명령만 실행하면 됩니다.

```bash
npm install
npm run dev
```

## 빌드

```bash
npm run build
```

빌드 결과물은 `dist/` 폴더에 생성됩니다.

## Vercel 배포

1. GitHub에 프로젝트를 업로드합니다.
2. Vercel에서 `Add New Project`를 선택합니다.
3. 해당 저장소를 import합니다.
4. Framework Preset은 `Vite`를 선택합니다.
5. Build Command는 `npm run build`를 사용합니다.
6. Output Directory는 `dist`를 사용합니다.
7. Deploy를 누릅니다.

## localStorage

저장 키는 아래 값을 사용합니다.

```text
monent-expenses
```
