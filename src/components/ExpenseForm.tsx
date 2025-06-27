
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { Expense } from "@/pages/Index";

interface ExpenseFormProps {
  onSubmit: (expense: Omit<Expense, 'id'>) => void;
  onCancel: () => void;
}

export const ExpenseForm = ({ onSubmit, onCancel }: ExpenseFormProps) => {
  const [formData, setFormData] = useState({
    partner: "" as "Sebi" | "Alex" | "",
    description: "",
    amount: "",
    date: new Date().toISOString().split('T')[0],
    category: "",
  });

  const categories = [
    "Elektronik",
    "Möbel",
    "Fahrzeug",
    "Kleidung",
    "Reise",
    "Sonstiges"
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.partner || !formData.description || !formData.amount || !formData.category) {
      alert("Bitte fülle alle Felder aus");
      return;
    }

    onSubmit({
      partner: formData.partner as "Sebi" | "Alex",
      description: formData.description,
      amount: parseFloat(formData.amount),
      date: formData.date,
      category: formData.category,
    });

    // Reset form
    setFormData({
      partner: "" as "Sebi" | "Alex" | "",
      description: "",
      amount: "",
      date: new Date().toISOString().split('T')[0],
      category: "",
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <Label htmlFor="partner">Partner</Label>
          <Select value={formData.partner} onValueChange={(value) => setFormData({...formData, partner: value as "Sebi" | "Alex"})}>
            <SelectTrigger>
              <SelectValue placeholder="Partner auswählen" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Sebi">Sebi</SelectItem>
              <SelectItem value="Alex">Alex</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div>
          <Label htmlFor="category">Kategorie</Label>
          <Select value={formData.category} onValueChange={(value) => setFormData({...formData, category: value})}>
            <SelectTrigger>
              <SelectValue placeholder="Kategorie auswählen" />
            </SelectTrigger>
            <SelectContent>
              {categories.map((category) => (
                <SelectItem key={category} value={category}>
                  {category}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div>
        <Label htmlFor="description">Beschreibung</Label>
        <Input
          id="description"
          type="text"
          placeholder="z.B. MacBook Pro für Homeoffice"
          value={formData.description}
          onChange={(e) => setFormData({...formData, description: e.target.value})}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <Label htmlFor="amount">Betrag (€)</Label>
          <Input
            id="amount"
            type="number"
            step="0.01"
            placeholder="0.00"
            value={formData.amount}
            onChange={(e) => setFormData({...formData, amount: e.target.value})}
          />
        </div>

        <div>
          <Label htmlFor="date">Datum</Label>
          <Input
            id="date"
            type="date"
            value={formData.date}
            onChange={(e) => setFormData({...formData, date: e.target.value})}
          />
        </div>
      </div>

      <div className="flex gap-3 pt-4">
        <Button type="submit" className="bg-blue-600 hover:bg-blue-700">
          Hinzufügen
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          Abbrechen
        </Button>
      </div>
    </form>
  );
};
