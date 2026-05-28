#!/bin/bash

# Simple test script for the assembly HTTP server

echo "=== Testing Assembly HTTP Server === "
echo

# Check if server is running
if ! pgrep -x "server" > /dev/null; then
    echo "Server not running. Start with: sudo ./server &"
    exit 1
fi

echo "Server is running"
echo

# Test 1: GET request
echo "Test 1: GET request"
echo "test content" > /tmp/assembly-test.txt
RESPONSE=$(curl -s http://localhost:80/tmp/assembly-test.txt)
if [ "$RESPONSE" = "test content" ]; then
    echo "GET request successful"
else
    echo "GET request failed"
fi
echo

# Test 2: POST request
echo "Test 2: POST request"
curl -s -X POST -d "posted data" http://localhost:80/tmp/assembly-post.txt > /dev/null
if [ -f /tmp/assembly-post.txt ] && [ "$(cat /tmp/assembly-post.txt)" = "posted data" ]; then
    echo "POST request successful"
else
    echo "POST request failed"
fi
echo

# Cleanup
sudo rm -f /tmp/assembly-test.txt /tmp/assembly-post.txt

echo "=== Tests complete === "