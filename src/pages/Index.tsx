
import { useState, useEffect } from "react";
import { ExpenseTracker } from "@/components/ExpenseTracker";

export interface Expense {
  id: string;
  partner: "Partner A" | "Partner B";
  description: string;
  amount: number;
  date: string;
  category: string;
}

const Index = () => {
  const [expenses, setExpenses] = useState<Expense[]>([]);

  // Load expenses from localStorage on component mount
  useEffect(() => {
    const savedExpenses = localStorage.getItem('firma-expenses');
    if (savedExpenses) {
      setExpenses(JSON.parse(savedExpenses));
    }
  }, []);

  // Save expenses to localStorage whenever expenses change
  useEffect(() => {
    localStorage.setItem('firma-expenses', JSON.stringify(expenses));
  }, [expenses]);

  const addExpense = (expense: Omit<Expense, 'id'>) => {
    const newExpense: Expense = {
      ...expense,
      id: Date.now().toString(),
    };
    setExpenses(prev => [...prev, newExpense]);
  };

  const deleteExpense = (id: string) => {
    setExpenses(prev => prev.filter(expense => expense.id !== id));
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <ExpenseTracker 
        expenses={expenses} 
        onAddExpense={addExpense}
        onDeleteExpense={deleteExpense}
      />
    </div>
  );
};

export default Index;
