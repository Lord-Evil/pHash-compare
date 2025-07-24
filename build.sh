#!/bin/bash

set -e  # Exit on any error

echo "=== pHash Compare Build Script ==="

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Please run this script from the project root."
    exit 1
fi

# Check for required tools
echo "Checking for required tools..."

if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found. Please install cmake first."
    echo "Gentoo: sudo emerge -av cmake"
    echo "Ubuntu/Debian: sudo apt install cmake"
    echo "Fedora: sudo dnf install cmake"
    echo "macOS: brew install cmake"
    exit 1
fi

if ! command -v pkg-config &> /dev/null; then
    echo "Error: pkg-config not found. Please install pkg-config first."
    echo "Gentoo: sudo emerge -av pkg-config"
    echo "Ubuntu/Debian: sudo apt install pkg-config"
    echo "Fedora: sudo dnf install pkg-config"
    echo "macOS: brew install pkg-config"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Error: git not found. Please install git first."
    echo "Gentoo: sudo emerge -av git"
    echo "Ubuntu/Debian: sudo apt install git"
    echo "Fedora: sudo dnf install git"
    echo "macOS: brew install git"
    exit 1
fi

echo "✓ All required tools found"

# Check for FFmpeg
echo "Checking for FFmpeg..."
if ! pkg-config --exists libavformat libavcodec libswscale libavutil; then
    echo "Warning: FFmpeg development libraries not found."
    echo "Install with:"
    echo "  Gentoo: sudo emerge -av media-video/ffmpeg"
    echo "  Ubuntu/Debian: sudo apt install libavformat-dev libavcodec-dev libswscale-dev libavutil-dev"
    echo "  Fedora: sudo dnf install ffmpeg-devel"
    echo "  macOS: brew install ffmpeg"
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
                echo "  Gentoo: sudo emerge -av media-libs/libjpeg-turbo"
                echo "  Ubuntu/Debian: sudo apt install libjpeg-dev"
                echo "  Fedora: sudo dnf install libjpeg-turbo-devel"
                echo "  macOS: brew install jpeg"
                ;;
            libpng)
                echo "  Gentoo: sudo emerge -av media-libs/libpng"
                echo "  Ubuntu/Debian: sudo apt install libpng-dev"
                echo "  Fedora: sudo dnf install libpng-devel"
                echo "  macOS: brew install libpng"
                ;;
            libtiff-4)
                echo "  Gentoo: sudo emerge -av media-libs/tiff"
                echo "  Ubuntu/Debian: sudo apt install libtiff-dev"
                echo "  Fedora: sudo dnf install libtiff-devel"
                echo "  macOS: brew install tiff"
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
    echo "CMake configuration failed. This might be due to missing dependencies."
    echo ""
    echo "For Gentoo, try installing these packages:"
    echo "  sudo emerge -av cmake git gcc pkg-config \\"
    echo "    media-video/ffmpeg \\"
    echo "    media-libs/libjpeg-turbo media-libs/libpng media-libs/tiff"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo apt install cmake git gcc pkg-config \\"
    echo "    libavformat-dev libavcodec-dev libswscale-dev libavutil-dev \\"
    echo "    libjpeg-dev libpng-dev libtiff-dev"
    echo ""
    echo "For Fedora:"
    echo "  sudo dnf install cmake git gcc pkg-config \\"
    echo "    ffmpeg-devel libjpeg-turbo-devel libpng-devel libtiff-devel"
    echo ""
    echo "For macOS:"
    echo "  brew install cmake git pkg-config ffmpeg jpeg libpng tiff"
    echo ""
    echo "Note: Some image libraries might be optional for video hashing."
    echo "The build will continue with available libraries."
    exit 1
fi

# Build the project
echo "Building project..."
make -j$(nproc)

echo "=== Build completed successfully! ==="
echo "Executable location: build/phash-compare"
echo ""
echo "To install system-wide:"
echo "  cd build && sudo make install"
echo ""
echo "To run the tool:"
echo "  ./build/phash-compare -h" 