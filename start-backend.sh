
#!/bin/bash

# Simple script to start the backend server
echo "🚀 Starting Expense Tracker Backend..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Navigate to backend directory
cd backend

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in backend directory"
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing backend dependencies..."
    npm install
fi

# Start the server
echo "🎯 Starting server on port 3001..."
echo "📋 Health check will be available at: http://localhost:3001/api/health"
echo "📋 API endpoints will be available at: http://localhost:3001/api/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

npm start
