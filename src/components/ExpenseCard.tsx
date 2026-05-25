import type { Expense } from '../types/expense';

type ExpenseCardProps = {
  expense: Expense;
  onDelete: (id: string) => void;
};

const formatter = new Intl.NumberFormat('ko-KR');

export function ExpenseCard({ expense, onDelete }: ExpenseCardProps) {
  return (
    <article className="expense-card">
      <div className="expense-card__image-wrap">
        <img className="expense-card__image" src={expense.cutoutImage} alt={expense.itemName} />
      </div>

      <div className="expense-card__content">
        <div>
          <h2 className="expense-card__title">{expense.itemName}</h2>
          <span className="expense-card__category">{expense.category}</span>
        </div>
        <strong className="expense-card__amount">{formatter.format(expense.amount)}원</strong>
      </div>

      <button
        className="expense-card__delete"
        type="button"
        aria-label={`${expense.itemName} 삭제`}
        onClick={() => onDelete(expense.id)}
      >
        삭제
      </button>
    </article>
  );
}
