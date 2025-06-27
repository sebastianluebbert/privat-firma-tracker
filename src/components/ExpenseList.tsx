
import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Trash2 } from "lucide-react";
import type { Expense } from "@/pages/Index";

interface ExpenseListProps {
  expenses: Expense[];
  onDeleteExpense: (id: string) => void;
}

export const ExpenseList = ({ expenses, onDeleteExpense }: ExpenseListProps) => {
  const [filterPartner, setFilterPartner] = useState<string>("all");
  const [filterCategory, setFilterCategory] = useState<string>("all");

  const categories = [...new Set(expenses.map(expense => expense.category))];

  const filteredExpenses = expenses.filter(expense => {
    const partnerMatch = filterPartner === "all" || expense.partner === filterPartner;
    const categoryMatch = filterCategory === "all" || expense.category === filterCategory;
    return partnerMatch && categoryMatch;
  });

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR'
    }).format(amount);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('de-DE');
  };

  const sortedExpenses = [...filteredExpenses].sort((a, b) => 
    new Date(b.date).getTime() - new Date(a.date).getTime()
  );

  return (
    <Card className="shadow-md">
      <CardHeader>
        <CardTitle>Ausgabenliste</CardTitle>
        
        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 mt-4">
          <div className="flex-1">
            <Select value={filterPartner} onValueChange={setFilterPartner}>
              <SelectTrigger>
                <SelectValue placeholder="Nach Partner filtern" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Alle Partner</SelectItem>
                <SelectItem value="Sebi">Sebi</SelectItem>
                <SelectItem value="Alex">Alex</SelectItem>
              </SelectContent>
            </Select>
          </div>
          
          <div className="flex-1">
            <Select value={filterCategory} onValueChange={setFilterCategory}>
              <SelectTrigger>
                <SelectValue placeholder="Nach Kategorie filtern" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Alle Kategorien</SelectItem>
                {categories.map(category => (
                  <SelectItem key={category} value={category}>
                    {category}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        <div className="space-y-4">
          {sortedExpenses.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <p>Keine Ausgaben gefunden.</p>
              <p className="text-sm mt-1">Füge deine erste Ausgabe hinzu!</p>
            </div>
          ) : (
            sortedExpenses.map((expense) => (
              <div
                key={expense.id}
                className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      expense.partner === "Sebi" 
                        ? "bg-blue-100 text-blue-800" 
                        : "bg-green-100 text-green-800"
                    }`}>
                      {expense.partner}
                    </span>
                    <span className="px-2 py-1 rounded-full text-xs bg-gray-100 text-gray-700">
                      {expense.category}
                    </span>
                  </div>
                  <h3 className="font-semibold text-gray-900 mb-1">
                    {expense.description}
                  </h3>
                  <p className="text-sm text-gray-500">
                    {formatDate(expense.date)}
                  </p>
                </div>
                
                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <div className="text-lg font-bold text-gray-900">
                      {formatCurrency(expense.amount)}
                    </div>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => {
                      if (window.confirm('Möchtest du diese Ausgabe wirklich löschen?')) {
                        onDeleteExpense(expense.id);
                      }
                    }}
                    className="text-red-600 hover:text-red-700 hover:bg-red-50"
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            ))
          )}
        </div>
      </CardContent>
    </Card>
  );
};
