
import { useState, useEffect } from "react";
import { ExpenseTracker } from "@/components/ExpenseTracker";
import { apiService } from "@/services/api";
import { useToast } from "@/hooks/use-toast";

export interface Expense {
  id: string;
  partner: "Sebi" | "Alex";
  description: string;
  amount: number;
  date: string;
  category: string;
}

const Index = () => {
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  // Load expenses from API on component mount
  useEffect(() => {
    loadExpenses();
  }, []);

  const loadExpenses = async () => {
    try {
      setLoading(true);
      const data = await apiService.getExpenses();
      setExpenses(data);
      console.log('Ausgaben geladen:', data.length);
    } catch (error) {
      console.error('Fehler beim Laden der Ausgaben:', error);
      // Fallback zu localStorage wenn API nicht verfügbar
      const savedExpenses = localStorage.getItem('firma-expenses');
      if (savedExpenses) {
        setExpenses(JSON.parse(savedExpenses));
        toast({
          title: "Offline-Modus",
          description: "Daten werden lokal gespeichert, da Server nicht erreichbar ist.",
          variant: "destructive",
        });
      }
    } finally {
      setLoading(false);
    }
  };

  const addExpense = async (expense: Omit<Expense, 'id'>) => {
    try {
      const newExpense = await apiService.addExpense(expense);
      setExpenses(prev => [...prev, newExpense]);
      toast({
        title: "Ausgabe hinzugefügt",
        description: `${expense.description} wurde erfolgreich gespeichert.`,
      });
      console.log('Neue Ausgabe hinzugefügt:', newExpense);
    } catch (error) {
      console.error('Fehler beim Hinzufügen der Ausgabe:', error);
      // Fallback zu localStorage
      const newExpense: Expense = {
        ...expense,
        id: Date.now().toString(),
      };
      setExpenses(prev => [...prev, newExpense]);
      localStorage.setItem('firma-expenses', JSON.stringify([...expenses, newExpense]));
      toast({
        title: "Offline hinzugefügt",
        description: "Ausgabe wurde lokal gespeichert.",
        variant: "destructive",
      });
    }
  };

  const deleteExpense = async (id: string) => {
    try {
      await apiService.deleteExpense(id);
      setExpenses(prev => prev.filter(expense => expense.id !== id));
      toast({
        title: "Ausgabe gelöscht",
        description: "Die Ausgabe wurde erfolgreich entfernt.",
      });
      console.log('Ausgabe gelöscht:', id);
    } catch (error) {
      console.error('Fehler beim Löschen der Ausgabe:', error);
      // Fallback zu localStorage
      const updatedExpenses = expenses.filter(expense => expense.id !== id);
      setExpenses(updatedExpenses);
      localStorage.setItem('firma-expenses', JSON.stringify(updatedExpenses));
      toast({
        title: "Offline gelöscht",
        description: "Ausgabe wurde lokal entfernt.",
        variant: "destructive",
      });
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Ausgaben werden geladen...</p>
        </div>
      </div>
    );
  }

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
