import type { Expense } from '../types/expense';

export const STORAGE_KEY = 'monent-expenses';

export function getExpenses(): Expense[] {
  const rawExpenses = localStorage.getItem(STORAGE_KEY);

  if (!rawExpenses) {
    return [];
  }

  try {
    const parsedExpenses = JSON.parse(rawExpenses);
    return Array.isArray(parsedExpenses) ? parsedExpenses : [];
  } catch {
    return [];
  }
}

export function saveExpenses(expenses: Expense[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(expenses));
}

export function addExpense(expense: Expense) {
  const expenses = getExpenses();
  saveExpenses([expense, ...expenses]);
}

export function deleteExpense(id: string) {
  const expenses = getExpenses();
  saveExpenses(expenses.filter((expense) => expense.id !== id));
}
