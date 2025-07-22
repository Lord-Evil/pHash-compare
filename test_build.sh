#!/bin/bash

set -e

echo "=== Testing pHash Video Compare Build ==="

# Build the project
echo "Building project..."
./build.sh

# Check if executable was created
if [ ! -f "build/phash_video_compare" ]; then
    echo "Error: Executable not found after build"
    exit 1
fi

echo "Build successful! Executable created at: build/phash_video_compare"

# Test help output
echo ""
echo "Testing help output..."
if ./build/phash_video_compare --help 2>&1 | grep -q "Usage:"; then
    echo "✓ Help output works correctly"
else
    echo "✗ Help output test failed"
    exit 1
fi

# Test version info
echo ""
echo "Testing version info..."
if ./build/phash_video_compare --version 2>&1 | grep -q "phash_video_compare"; then
    echo "✓ Version info works correctly"
else
    echo "✗ Version info test failed"
    exit 1
fi

# Check library dependencies
echo ""
echo "Checking library dependencies..."
if ldd build/phash_video_compare | grep -q "pHash"; then
    echo "✗ pHash library found in dependencies (should be statically linked)"
    exit 1
else
    echo "✓ pHash library statically linked (not in dependencies)"
fi

echo ""
echo "=== All tests passed! ==="
echo "The build is working correctly."
echo ""
echo "You can now use the tool:"
echo "  ./build/phash_video_compare --help"
echo "  ./build/phash_video_compare -j 12 -s hashes.db -w *.mp4" 