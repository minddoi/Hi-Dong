import { useEffect, useMemo, useState } from 'react';
import { AddExpenseModal } from './components/AddExpenseModal';
import { ExpenseCard } from './components/ExpenseCard';
import type { Expense } from './types/expense';
import { addExpense, deleteExpense, getExpenses } from './utils/storage';

const formatter = new Intl.NumberFormat('ko-KR');

function getTodayDate() {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, '0');
  const date = String(today.getDate()).padStart(2, '0');

  return `${year}-${month}-${date}`;
}

function App() {
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    setExpenses(getExpenses());
  }, []);

  const todayExpenses = useMemo(() => {
    const today = getTodayDate();
    return expenses.filter((expense) => expense.date === today);
  }, [expenses]);

  const todayTotal = useMemo(() => {
    return todayExpenses.reduce((sum, expense) => sum + expense.amount, 0);
  }, [todayExpenses]);

  function handleSave(expense: Expense) {
    addExpense(expense);
    setExpenses(getExpenses());
    setIsModalOpen(false);
  }

  function handleDelete(id: string) {
    deleteExpense(id);
    setExpenses(getExpenses());
  }

  return (
    <main className="app-shell">
      <header className="home-header">
        <p className="home-header__date">{getTodayDate()}</p>
        <h1>오늘의 지출</h1>
      </header>

      <section className="summary-panel" aria-label="오늘 총 지출">
        <span>오늘 총 지출</span>
        <strong>{formatter.format(todayTotal)}원</strong>
      </section>

      <section className="expense-list" aria-label="오늘 지출 리스트">
        {todayExpenses.length > 0 ? (
          todayExpenses.map((expense) => (
            <ExpenseCard key={expense.id} expense={expense} onDelete={handleDelete} />
          ))
        ) : (
          <div className="empty-state">
            <p>아직 저장된 지출이 없어요.</p>
            <span>오른쪽 아래 버튼으로 첫 지출을 추가해보세요.</span>
          </div>
        )}
      </section>

      <button
        className="floating-button"
        type="button"
        aria-label="사진으로 지출 추가"
        onClick={() => setIsModalOpen(true)}
      >
        +
      </button>

      {isModalOpen && <AddExpenseModal onClose={() => setIsModalOpen(false)} onSave={handleSave} />}
    </main>
  );
}

export default App;
