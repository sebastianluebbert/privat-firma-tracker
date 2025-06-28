
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

# Find the backend directory
BACKEND_DIR=""

if [ -d "backend" ]; then
    BACKEND_DIR="backend"
elif [ -d "../backend" ]; then
    BACKEND_DIR="../backend"
elif [ -f "server.js" ]; then
    BACKEND_DIR="."
else
    echo "❌ Backend directory not found!"
    echo "Looking for one of:"
    echo "  - ./backend/"
    echo "  - ../backend/"
    echo "  - ./server.js"
    echo ""
    echo "Current directory contents:"
    ls -la
    exit 1
fi

echo "📂 Using backend directory: $BACKEND_DIR"

# Navigate to backend directory
cd "$BACKEND_DIR"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in $BACKEND_DIR"
    echo "Directory contents:"
    ls -la
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing backend dependencies..."
    npm install
fi

# Check if server.js exists
if [ ! -f "server.js" ]; then
    echo "❌ server.js not found in $BACKEND_DIR"
    echo "Available files:"
    ls -la *.js 2>/dev/null || echo "No .js files found"
    exit 1
fi

# Start the server
echo "🎯 Starting server on port 3001..."
echo "📋 Health check will be available at: http://localhost:3001/api/health"
echo "📋 API endpoints will be available at: http://localhost:3001/api/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

npm start
