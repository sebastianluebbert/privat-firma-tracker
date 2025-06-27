
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Expense } from "@/pages/Index";

interface BalanceOverviewProps {
  expenses: Expense[];
}

export const BalanceOverview = ({ expenses }: BalanceOverviewProps) => {
  const partnerATotal = expenses
    .filter(expense => expense.partner === "Partner A")
    .reduce((sum, expense) => sum + expense.amount, 0);

  const partnerBTotal = expenses
    .filter(expense => expense.partner === "Partner B")
    .reduce((sum, expense) => sum + expense.amount, 0);

  const totalExpenses = partnerATotal + partnerBTotal;
  const averagePerPartner = totalExpenses / 2;
  
  const partnerABalance = partnerATotal - averagePerPartner;
  const partnerBBalance = partnerBTotal - averagePerPartner;

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR'
    }).format(amount);
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <Card className="shadow-md border-l-4 border-l-blue-500">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Partner A</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-gray-900">
            {formatCurrency(partnerATotal)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            Gesamtausgaben
          </div>
        </CardContent>
      </Card>

      <Card className="shadow-md border-l-4 border-l-green-500">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Partner B</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-gray-900">
            {formatCurrency(partnerBTotal)}
          </div>
          <div className="text-sm text-gray-500 mt-1">
            Gesamtausgaben
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

      <Card className={`shadow-md border-l-4 ${Math.abs(partnerABalance) < 0.01 ? 'border-l-gray-400' : partnerABalance > 0 ? 'border-l-red-500' : 'border-l-orange-500'}`}>
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-medium text-gray-600">Saldo</CardTitle>
        </CardHeader>
        <CardContent>
          {Math.abs(partnerABalance) < 0.01 ? (
            <div>
              <div className="text-2xl font-bold text-green-600">
                Ausgeglichen
              </div>
              <div className="text-sm text-gray-500 mt-1">
                Keine Schulden
              </div>
            </div>
          ) : partnerABalance > 0 ? (
            <div>
              <div className="text-xl font-bold text-red-600">
                B schuldet A
              </div>
              <div className="text-lg font-semibold text-gray-900">
                {formatCurrency(Math.abs(partnerABalance))}
              </div>
            </div>
          ) : (
            <div>
              <div className="text-xl font-bold text-orange-600">
                A schuldet B
              </div>
              <div className="text-lg font-semibold text-gray-900">
                {formatCurrency(Math.abs(partnerBBalance))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};
