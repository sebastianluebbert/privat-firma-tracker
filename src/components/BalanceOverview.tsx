
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Expense } from "@/pages/Index";

interface BalanceOverviewProps {
  expenses: Expense[];
  onPartnerClick: (partner: "Sebi" | "Alex") => void;
  selectedPartner?: "Sebi" | "Alex" | null;
}

export const BalanceOverview = ({ expenses, onPartnerClick, selectedPartner }: BalanceOverviewProps) => {
  const sebiTotal = expenses
    .filter(expense => expense.partner === "Sebi")
    .reduce((sum, expense) => sum + expense.amount, 0);

  const alexTotal = expenses
    .filter(expense => expense.partner === "Alex")
    .reduce((sum, expense) => sum + expense.amount, 0);

  const sebiCount = expenses.filter(expense => expense.partner === "Sebi").length;
  const alexCount = expenses.filter(expense => expense.partner === "Alex").length;

  const totalExpenses = sebiTotal + alexTotal;
  const averagePerPartner = totalExpenses / 2;
  
  const sebiBalance = sebiTotal - averagePerPartner;
  const alexBalance = alexTotal - averagePerPartner;
  const difference = Math.abs(sebiTotal - alexTotal);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR'
    }).format(amount);
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-5 gap-6 mb-8">
      <Card 
        className={`shadow-md border-l-4 border-l-blue-500 cursor-pointer transition-all hover:shadow-lg hover:scale-105 ${
          selectedPartner === "Sebi" ? "ring-2 ring-blue-300 bg-blue-50" : ""
        }`}
        onClick={() => onPartnerClick("Sebi")}
      >
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Sebi</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-gray-900">
            {formatCurrency(sebiTotal)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            {sebiCount} Ausgaben
          </div>
        </CardContent>
      </Card>

      <Card 
        className={`shadow-md border-l-4 border-l-green-500 cursor-pointer transition-all hover:shadow-lg hover:scale-105 ${
          selectedPartner === "Alex" ? "ring-2 ring-green-300 bg-green-50" : ""
        }`}
        onClick={() => onPartnerClick("Alex")}
      >
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Alex</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-gray-900">
            {formatCurrency(alexTotal)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            {alexCount} Ausgaben
          </div>
        </CardContent>
      </Card>

      <Card className="shadow-md border-l-4 border-l-purple-500">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Gesamtsumme</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-gray-900">
            {formatCurrency(totalExpenses)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            Alle Ausgaben
          </div>
        </CardContent>
      </Card>

      <Card className="shadow-md border-l-4 border-l-yellow-500">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Differenz</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-yellow-600">
            {formatCurrency(difference)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            {sebiTotal > alexTotal ? "Sebi liegt vorn" : alexTotal > sebiTotal ? "Alex liegt vorn" : "Ausgeglichen"}
          </div>
        </CardContent>
      </Card>

      <Card className={`shadow-md border-l-4 ${Math.abs(sebiBalance) < 0.01 ? 'border-l-gray-400' : sebiBalance > 0 ? 'border-l-red-500' : 'border-l-orange-500'}`}>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Saldo</CardTitle>
        </CardHeader>
        <CardContent>
          {Math.abs(sebiBalance) < 0.01 ? (
            <div>
              <div className="text-2xl font-bold text-green-600">
                Ausgeglichen
              </div>
              <div className="text-sm text-gray-500 mt-1">
                Keine Schulden
              </div>
            </div>
          ) : sebiBalance > 0 ? (
            <div>
              <div className="text-xl font-bold text-red-600">
                Alex schuldet Sebi
              </div>
              <div className="text-lg font-semibold text-gray-900">
                {formatCurrency(Math.abs(sebiBalance))}
              </div>
            </div>
          ) : (
            <div>
              <div className="text-xl font-bold text-orange-600">
                Sebi schuldet Alex
              </div>
              <div className="text-lg font-semibold text-gray-900">
                {formatCurrency(Math.abs(alexBalance))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};
