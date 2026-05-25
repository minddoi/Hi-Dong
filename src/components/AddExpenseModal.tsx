import { ChangeEvent, FormEvent, useMemo, useState } from 'react';
import type { Expense } from '../types/expense';
import { fileToBase64, removeBackgroundFromImage } from '../utils/imageCutout';

type AddExpenseModalProps = {
  onClose: () => void;
  onSave: (expense: Expense) => void;
};

const categories = [
  { value: '식비', label: '식비' },
  { value: '카페', label: '카페' },
  { value: '쇼핑', label: '쇼핑' },
  { value: '교통', label: '교통' },
  { value: '생활', label: '생활' },
  { value: '기타', label: '기타' },
];

function getTodayDate() {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const date = String(today.getDate()).padStart(2, '0');

  return `${year}-${month}-${date}`;
}

function createExpenseId() {
  if ('randomUUID' in crypto) {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function AddExpenseModal({ onClose, onSave }: AddExpenseModalProps) {
  const [itemName, setItemName] = useState('');
  const [amount, setAmount] = useState('');
  const [category, setCategory] = useState(categories[0].value);
  const [originalImage, setOriginalImage] = useState('');
  const [cutoutImage, setCutoutImage] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const canSave = useMemo(() => {
    return itemName.trim().length > 0 && Number(amount) > 0 && originalImage.length > 0;
  }, [amount, itemName, originalImage]);

  async function handleImageChange(event: ChangeEvent<HTMLInputElement>) {
    const selectedFile = event.target.files?.[0];

    if (!selectedFile) {
      return;
    }

    setErrorMessage('');
    setIsProcessing(true);

    try {
      const base64Image = await fileToBase64(selectedFile);
      setOriginalImage(base64Image);
      setCutoutImage('');

      try {
        const removedBackgroundImage = await removeBackgroundFromImage(selectedFile);
        setCutoutImage(removedBackgroundImage);
      } catch {
        setCutoutImage(base64Image);
        setErrorMessage('누끼 처리에 실패해서 원본 이미지로 저장합니다.');
      }
    } catch {
      setOriginalImage('');
      setCutoutImage('');
      setErrorMessage('이미지를 불러오지 못했습니다. 다른 사진을 선택해주세요.');
    } finally {
      setIsProcessing(false);
    }
  }

  function handleAmountChange(event: ChangeEvent<HTMLInputElement>) {
    setAmount(event.target.value.replace(/\D/g, ''));
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!canSave) {
      return;
    }

    onSave({
      id: createExpenseId(),
      itemName: itemName.trim(),
      amount: Number(amount),
      category,
      date: getTodayDate(),
      originalImage,
      cutoutImage: cutoutImage || originalImage,
    });
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal" role="dialog" aria-modal="true" aria-labelledby="add-expense-title">
        <header className="modal__header">
          <div>
            <p className="modal__eyebrow">새 지출</p>
            <h2 id="add-expense-title">사진으로 추가</h2>
          </div>
          <button className="icon-button" type="button" aria-label="닫기" onClick={onClose}>
            ×
          </button>
        </header>

        <form className="add-form" onSubmit={handleSubmit}>
          <label className="photo-picker">
            <span>사진 촬영/선택</span>
            <input type="file" accept="image/*" capture="environment" onChange={handleImageChange} />
          </label>

          {(originalImage || cutoutImage || isProcessing) && (
            <div className="preview-grid">
              <div className="preview-box">
                <span>원본</span>
                {originalImage ? <img src={originalImage} alt="선택한 원본" /> : <div className="preview-empty" />}
              </div>

              <div className="preview-box preview-box--cutout">
                <span>누끼</span>
                {isProcessing ? (
                  <div className="loading">
                    <div className="loading__spinner" />
                    <p>이미지 처리 중</p>
                  </div>
                ) : cutoutImage ? (
                  <img src={cutoutImage} alt="배경 제거 결과" />
                ) : (
                  <div className="preview-empty" />
                )}
              </div>
            </div>
          )}

          {errorMessage && <p className="form-error">{errorMessage}</p>}

          <label className="field">
            <span>물건명</span>
            <input
              type="text"
              value={itemName}
              placeholder="예: 샌드위치"
              onChange={(event) => setItemName(event.target.value)}
            />
          </label>

          <label className="field">
            <span>가격</span>
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              value={amount}
              placeholder="예: 8500"
              onChange={handleAmountChange}
            />
          </label>

          <fieldset className="category-field">
            <legend>카테고리</legend>
            <div className="category-options">
              {categories.map((option) => (
                <label
                  key={option.value}
                  className={`category-chip ${category === option.value ? 'category-chip--active' : ''}`}
                >
                  <input
                    type="radio"
                    name="category"
                    value={option.value}
                    checked={category === option.value}
                    onChange={(event) => setCategory(event.target.value)}
                  />
                  <span>{option.label}</span>
                </label>
              ))}
            </div>
          </fieldset>

          <div className="modal-actions">
            <button className="secondary-button" type="button" onClick={onClose}>
              취소
            </button>
            <button className="primary-button" type="submit" disabled={!canSave || isProcessing}>
              저장
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
