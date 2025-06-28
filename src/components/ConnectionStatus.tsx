
import { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { AlertCircle, CheckCircle, RefreshCw, Terminal } from 'lucide-react';
import { apiService } from '@/services/api';

export const ConnectionStatus = () => {
  const [isConnected, setIsConnected] = useState<boolean | null>(null);
  const [isChecking, setIsChecking] = useState(false);
  const [lastChecked, setLastChecked] = useState<Date | null>(null);

  const checkConnection = async () => {
    setIsChecking(true);
    try {
      const connected = await apiService.testConnection();
      setIsConnected(connected);
      setLastChecked(new Date());
    } catch (error) {
      setIsConnected(false);
      setLastChecked(new Date());
    }
    setIsChecking(false);
  };

  useEffect(() => {
    checkConnection();
    
    // Check connection every 30 seconds
    const interval = setInterval(checkConnection, 30000);
    return () => clearInterval(interval);
  }, []);

  if (isConnected === null) {
    return null; // Don't show anything while initial check is happening
  }

  return (
    <Card className={`mb-4 ${isConnected ? 'border-green-200 bg-green-50' : 'border-red-200 bg-red-50'}`}>
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            {isConnected ? (
              <CheckCircle className="h-5 w-5 text-green-600" />
            ) : (
              <AlertCircle className="h-5 w-5 text-red-600" />
            )}
            
            <div>
              <div className={`font-medium ${isConnected ? 'text-green-800' : 'text-red-800'}`}>
                {isConnected ? 'Backend verbunden' : 'Backend nicht erreichbar'}
              </div>
              {lastChecked && (
                <div className="text-sm text-gray-600">
                  Letzter Check: {lastChecked.toLocaleTimeString()}
                </div>
              )}
              
              {!isConnected && (
                <div className="text-sm text-red-700 mt-2 space-y-1">
                  <div className="flex items-center gap-2">
                    <Terminal className="h-4 w-4" />
                    <span className="font-medium">So startest du das Backend:</span>
                  </div>
                  <div className="ml-6 space-y-1">
                    <div>1. <code className="bg-red-100 px-2 py-1 rounded text-xs">chmod +x start-backend.sh</code></div>
                    <div>2. <code className="bg-red-100 px-2 py-1 rounded text-xs">./start-backend.sh</code></div>
                  </div>
                  <div className="text-xs text-red-600 mt-2">
                    Oder manuell: <code className="bg-red-100 px-1 rounded">cd backend && npm install && npm start</code>
                  </div>
                </div>
              )}
            </div>
          </div>
          
          <Button
            variant="outline"
            size="sm"
            onClick={checkConnection}
            disabled={isChecking}
            className="flex items-center gap-2"
          >
            <RefreshCw className={`h-4 w-4 ${isChecking ? 'animate-spin' : ''}`} />
            {isChecking ? 'Prüfe...' : 'Neu prüfen'}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};
