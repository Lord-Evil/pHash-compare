#!/bin/bash

set -e  # Exit on any error

echo "=== pHash Video Compare Build Script ==="

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Please run this script from the project root."
    exit 1
fi

# Check for required tools
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found. Please install cmake first."
    echo "Gentoo: sudo emerge -av cmake"
    exit 1
fi

if ! command -v pkg-config &> /dev/null; then
    echo "Error: pkg-config not found. Please install pkg-config first."
    echo "Gentoo: sudo emerge -av pkg-config"
    exit 1
fi

# Initialize and update submodules
echo "Initializing pHash submodule..."
git submodule update --init --recursive

# Create build directory
echo "Creating build directory..."
mkdir -p build
cd build

# Configure with CMake
echo "Configuring with CMake..."
if ! cmake .. \
    -DWITH_VIDEO_HASH=ON \
    -DPHASH_DYNAMIC=OFF \
    -DPHASH_STATIC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local; then
    
    echo ""
    echo "CMake configuration failed. This might be due to missing dependencies."
    echo ""
    echo "For Gentoo, try installing these packages:"
    echo "  sudo emerge -av cmake git gcc pkg-config \\"
    echo "    media-video/ffmpeg \\"
    echo "    media-libs/libjpeg-turbo media-libs/libpng media-libs/tiff"
    echo ""
    echo "Note: Some image libraries might be optional for video hashing."
    echo "The build will continue with available libraries."
    exit 1
fi

# Build the project
echo "Building project..."
make -j$(nproc)

echo "=== Build completed successfully! ==="
echo "Executable location: build/phash_video_compare"
echo ""
echo "To install system-wide:"
echo "  cd build && sudo make install"
echo ""
echo "To run the tool:"
echo "  ./build/phash_video_compare --help" 