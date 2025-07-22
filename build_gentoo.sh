#!/bin/bash

set -e  # Exit on any error

echo "=== pHash Video Compare Build Script (Gentoo) ==="

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Please run this script from the project root."
    exit 1
fi

# Check for required tools
echo "Checking for required tools..."

if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found."
    echo "Install with: sudo emerge -av cmake"
    exit 1
fi

if ! command -v pkg-config &> /dev/null; then
    echo "Error: pkg-config not found."
    echo "Install with: sudo emerge -av pkg-config"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Error: git not found."
    echo "Install with: sudo emerge -av git"
    exit 1
fi

echo "✓ All required tools found"

# Check for FFmpeg
echo "Checking for FFmpeg..."
if ! pkg-config --exists libavformat libavcodec libswscale libavutil; then
    echo "Warning: FFmpeg development libraries not found."
    echo "Install with: sudo emerge -av media-video/ffmpeg"
    echo "Note: This might be required for video hashing."
    echo "Continuing anyway..."
else
    echo "✓ FFmpeg found"
fi

# Check for image libraries
echo "Checking for image libraries..."
for lib in libjpeg libpng libtiff-4; do
    if pkg-config --exists $lib; then
        echo "✓ $lib found"
    else
        echo "Warning: $lib not found"
        case $lib in
            libjpeg)
                echo "  Install with: sudo emerge -av media-libs/libjpeg-turbo"
                ;;
            libpng)
                echo "  Install with: sudo emerge -av media-libs/libpng"
                ;;
            libtiff-4)
                echo "  Install with: sudo emerge -av media-libs/tiff"
                ;;
        esac
    fi
done

echo "Note: Some image libraries might be optional for video hashing."

# Initialize and update submodules
echo ""
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
    echo "CMake configuration failed."
    echo ""
    echo "Try installing missing dependencies:"
    echo "  sudo emerge -av cmake git gcc pkg-config \\"
    echo "    media-video/ffmpeg \\"
    echo "    media-libs/libjpeg-turbo media-libs/libpng media-libs/tiff"
    echo ""
    echo "If the issue persists, try building manually:"
    echo "  cd build"
    echo "  cmake .. -DWITH_VIDEO_HASH=ON"
    echo "  make -j$(nproc)"
    exit 1
fi

# Build the project
echo "Building project..."
make -j$(nproc)

echo ""
echo "=== Build completed successfully! ==="
echo "Executable location: build/phash_video_compare"
echo ""
echo "To install system-wide:"
echo "  cd build && sudo make install"
echo ""
echo "To run the tool:"
echo "  ./build/phash_video_compare --help"
echo ""
echo "To test the build:"
echo "  ./test_build.sh" 