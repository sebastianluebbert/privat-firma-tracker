
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

export interface ApiExpense {
  id: string;
  partner: "Sebi" | "Alex";
  description: string;
  amount: number;
  date: string;
  category: string;
}

class ApiService {
  private async request<T>(
    endpoint: string, 
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${API_BASE_URL}/api${endpoint}`;
    
    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    console.log(`API Request: ${config.method || 'GET'} ${url}`);
    
    const response = await fetch(url, config);
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API Error ${response.status}: ${errorText}`);
    }
    
    return response.json();
  }

  async getExpenses(): Promise<ApiExpense[]> {
    return this.request<ApiExpense[]>('/expenses');
  }

  async addExpense(expense: Omit<ApiExpense, 'id'>): Promise<ApiExpense> {
    return this.request<ApiExpense>('/expenses', {
      method: 'POST',
      body: JSON.stringify(expense),
    });
  }

  async deleteExpense(id: string): Promise<void> {
    await this.request(`/expenses/${id}`, {
      method: 'DELETE',
    });
  }

  async checkHealth(): Promise<{ status: string; message: string }> {
    return this.request<{ status: string; message: string }>('/health');
  }
}

export const apiService = new ApiService();
