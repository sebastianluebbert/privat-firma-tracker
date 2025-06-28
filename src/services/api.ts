
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
    const url = import.meta.env.DEV 
      ? `${API_BASE_URL}${endpoint}`
      : endpoint; // Use relative URLs in production (served through Nginx proxy)
    
    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    console.log(`🔗 API Request: ${config.method || 'GET'} ${url}`);
    console.log(`🌍 Environment: ${import.meta.env.DEV ? 'Development' : 'Production'}`);
    console.log(`🎯 Base URL: ${API_BASE_URL}`);
    
    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`❌ API Error ${response.status}: ${errorText}`);
        throw new Error(`API Error ${response.status}: ${errorText}`);
      }
      
      const data = await response.json();
      console.log(`✅ API Success: ${config.method || 'GET'} ${url}`);
      return data;
    } catch (error) {
      console.error(`💥 Fetch Error for ${url}:`, error);
      
      // More specific error handling
      if (error instanceof TypeError && error.message.includes('fetch')) {
        // This is likely a connection refused error
        console.error('🚫 Connection refused - Backend server is not running or not accessible');
        console.error('💡 To fix this:');
        console.error('1. Make sure the backend server is running on port 3001');
        console.error('2. Check if you can access http://localhost:3001/api/health directly');
        console.error('3. Verify the backend is properly configured');
        
        throw new Error(`❌ Verbindung zum Backend fehlgeschlagen! 
        
Der Backend-Server auf ${API_BASE_URL} ist nicht erreichbar.

🔧 Lösungsschritte:
1. Backend-Server starten: cd backend && npm start
2. Health-Check testen: http://localhost:3001/api/health
3. Bei Deploy-Problemen: ./deploy.sh ausführen`);
      }
      throw error;
    }
  }

  // Add a connection test method
  async testConnection(): Promise<boolean> {
    try {
      await this.checkHealth();
      return true;
    } catch (error) {
      console.error('Connection test failed:', error);
      return false;
    }
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
