
// Use relative URLs in production, localhost in development
const API_BASE_URL = import.meta.env.VITE_API_URL || (
  import.meta.env.DEV ? 'http://localhost:3001' : ''
);

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
    // Construct URL properly for both development and production
    let url: string;
    if (import.meta.env.DEV) {
      // Development: use full localhost URL
      url = `${API_BASE_URL}${endpoint}`;
    } else {
      // Production: use relative URLs (served through Nginx proxy)
      url = endpoint;
    }
    
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
      console.error(`API Error ${response.status}: ${errorText}`);
      throw new Error(`API Error ${response.status}: ${errorText}`);
    }
    
    return response.json();
  }

  async getExpenses(): Promise<ApiExpense[]> {
    return this.request<ApiExpense[]>('/api/expenses');
  }

  async addExpense(expense: Omit<ApiExpense, 'id'>): Promise<ApiExpense> {
    return this.request<ApiExpense>('/api/expenses', {
      method: 'POST',
      body: JSON.stringify(expense),
    });
  }

  async deleteExpense(id: string): Promise<void> {
    await this.request(`/api/expenses/${id}`, {
      method: 'DELETE',
    });
  }

  async checkHealth(): Promise<{ status: string; message: string }> {
    return this.request<{ status: string; message: string }>('/api/health');
  }
}

export const apiService = new ApiService();
