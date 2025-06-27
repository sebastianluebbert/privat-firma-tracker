
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Plus, X } from "lucide-react";
import { useState } from "react";
import { ExpenseForm } from "./ExpenseForm";
import { ExpenseList } from "./ExpenseList";
import { BalanceOverview } from "./BalanceOverview";
import type { Expense } from "@/pages/Index";

interface ExpenseTrackerProps {
  expenses: Expense[];
  onAddExpense: (expense: Omit<Expense, 'id'>) => void;
  onDeleteExpense: (id: string) => void;
}

export const ExpenseTracker = ({ expenses, onAddExpense, onDeleteExpense }: ExpenseTrackerProps) => {
  const [showForm, setShowForm] = useState(false);
  const [selectedPartner, setSelectedPartner] = useState<"Sebi" | "Alex" | null>(null);

  const filteredExpenses = selectedPartner 
    ? expenses.filter(expense => expense.partner === selectedPartner)
    : expenses;

  return (
    <div className="container mx-auto p-6 max-w-6xl">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Private Ausgaben Tracker
        </h1>
        <p className="text-gray-600">
          Verwalte und verfolge private Anschaffungen aus der Firma
        </p>
      </div>

      {/* Balance Overview */}
      <BalanceOverview 
        expenses={expenses} 
        onPartnerClick={setSelectedPartner}
        selectedPartner={selectedPartner}
      />

      {/* Filter indicator */}
      {selectedPartner && (
        <div className="mb-6 flex items-center gap-3">
          <div className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-medium">
            Nur {selectedPartner}'s Ausgaben angezeigt
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setSelectedPartner(null)}
            className="text-gray-600 hover:text-gray-800"
          >
            <X className="h-4 w-4 mr-1" />
            Alle anzeigen
          </Button>
        </div>
      )}

      {/* Add Expense Button */}
      <div className="mb-6">
        <Button 
          onClick={() => setShowForm(!showForm)}
          className="bg-blue-600 hover:bg-blue-700 text-white"
          size="lg"
        >
          <Plus className="mr-2 h-5 w-5" />
          Ausgabe hinzufügen
        </Button>
      </div>

      {/* Add Expense Form */}
      {showForm && (
        <Card className="mb-6 shadow-md">
          <CardHeader>
            <CardTitle>Neue Ausgabe hinzufügen</CardTitle>
          </CardHeader>
          <CardContent>
            <ExpenseForm 
              onSubmit={(expense) => {
                onAddExpense(expense);
                setShowForm(false);
              }}
              onCancel={() => setShowForm(false)}
            />
          </CardContent>
        </Card>
      )}

      {/* Expenses List */}
      <ExpenseList expenses={filteredExpenses} onDeleteExpense={onDeleteExpense} />
    </div>
  );
};
