# pHash Compare Tool

A fast, multithreaded tool for detecting duplicate videos and images using perceptual hashing. Built with CMake and using the [pHash library](https://github.com/Lord-Evil/pHash) as a submodule.

## Features

- **Perceptual Hashing**: Uses pHash library to generate video and image fingerprints
- **Dual Mode**: Support for both video (`-v`) and image (`-i`) hashing
- **Multithreading**: Parallel hash computation with `-j` flag (like `make`)
- **Hash Caching**: Stores computed hashes in database files
- **Recursive Search**: Automatically find files in directories and subdirectories
- **File Type Filtering**: Filter by file extensions
- **Stdin Support**: Read file lists from standard input
- **Flexible Comparison**: Configurable similarity thresholds
- **Multiple Workflows**: Support for different usage patterns

## Prerequisites

- CMake 3.16 or higher
- Git (for submodules)
- FFmpeg development libraries
- Image libraries (libjpeg, libpng, libtiff)
- C++17 compatible compiler

### Installing Dependencies

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install cmake git build-essential pkg-config \
    libavformat-dev libavcodec-dev libswscale-dev libavutil-dev \
    libjpeg-dev libpng-dev libtiff-dev
```

#### Gentoo:
```bash
sudo emerge -av cmake git gcc pkg-config \
    media-video/ffmpeg \
    media-libs/libjpeg-turbo media-libs/libpng media-libs/tiff
```

## Building

### Quick Build (Recommended)

Use the provided build script:

```bash
./build.sh
```

For Gentoo users, there's also a Gentoo-specific build script that provides better error messages:

```bash
./build_gentoo.sh
```

These scripts will:
1. Initialize the pHash submodule
2. Create a build directory
3. Configure CMake with `-DWITH_VIDEO_HASH=ON`
4. Build the project with all available CPU cores

### Manual Build

If you prefer to build manually:

```bash
# Initialize submodules
git submodule update --init --recursive

# Create build directory
mkdir build && cd build

# Configure with CMake
cmake .. -DWITH_VIDEO_HASH=ON -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc)

# Optional: Install system-wide
sudo make install
```

## Usage

### Basic Usage

**Important**: You must specify either `-i` (image mode) or `-v` (video mode).

```bash
# Compare images with default settings
./build/phash-compare -i *.jpg

# Compare videos with 12 threads for faster processing
./build/phash-compare -v -j 12 -s hashes.db -w *.mp4

# Generate hashes only (no comparison)
./build/phash-compare -i -j 12 -g -s hashes.db *.jpg
```

### Advanced Usage

```bash
# Recursive search for videos in multiple directories
./build/phash-compare -v -r ./videos -r ./backup -t mp4 -t webm -s hashes.db -w

# Find duplicate images with strict threshold
./build/phash-compare -i -r ./photos -t jpg -t png -d 3 -s image_hashes.db -w

# Use stdin for file list
find . -name "*.mp4" | ./build/phash-compare -v -s hashes.db -w

# High-performance processing
./build/phash-compare -v -j 12 -r ./videos -t mp4 -d 5 -s hashes.db -w
```

### Integration with fetch_urls.sh

Update your `fetch_urls.sh` script to use the new tool name and explicit video mode:

```bash
# Check for and remove duplicate video files by perceptual hash
cd ..
echo "Checking for perceptually similar videos..."

# Create hash database file for this user
hash_db="$USERNAME/video_hashes.db"

# Generate hashes for new videos and compare all videos (including existing ones)
echo "Generating hashes and comparing videos..."
./build/phash-compare -v -j 12 -d 5 -s "$hash_db" -w ./$USERNAME/*.mp4 2>/dev/null | while read -r line; do
    # Parse the new format: "distance - file1 - file2"
    # Extract the second filename (the one to remove)
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate video: $dupfile"
        rm -- "$dupfile"
    fi
done
```

## Project Structure

```
.
├── CMakeLists.txt          # Main CMake configuration
├── .gitmodules             # Git submodule configuration
├── build.sh               # Build script
├── phash-compare.cpp      # Main source code
├── MANUAL.md              # Detailed manual
├── README.md              # This file
└── third_party/
    └── pHash/             # pHash library submodule
```

## CMake Configuration

The CMake build system:

- **Automatically finds dependencies** using pkg-config
- **Builds pHash with video support** (`-DWITH_VIDEO_HASH=ON`)
- **Builds pHash as static library** (`-DPHASH_STATIC=ON`) for better portability
- **Links all required libraries** (FFmpeg, image libraries, pthreads)
- **Provides install targets** for system-wide installation

### CMake Options

- `-DWITH_VIDEO_HASH=ON`: Enable video hashing in pHash (required)
- `-DPHASH_STATIC=ON`: Build pHash as static library (default)
- `-DPHASH_DYNAMIC=OFF`: Disable dynamic library build (default)
- `-DCMAKE_BUILD_TYPE=Release`: Optimized release build
- `-DCMAKE_INSTALL_PREFIX=/usr/local`: Installation prefix

## Command Line Options

- `-i`: Image hash mode (must specify either -i or -v)
- `-v`: Video hash mode (must specify either -i or -v)
- `-d threshold`: Only show files with distance ≤ threshold
- `-s source_file`: Load existing hashes from database file
- `-w`: Write new hashes to database file
- `-g`: Generate hashes only (no comparison, implies -w)
- `-j jobs`: Number of parallel jobs (default: 1)
- `-r directory`: Recursively search directory for files
- `-t extension`: Filter by file extension (can be used multiple times)

## Troubleshooting

### Build Issues

1. **"Could not find FFmpeg"**
   - Install FFmpeg development packages
   - Ensure pkg-config can find them

2. **"Could not find pHash"**
   - Run `git submodule update --init --recursive`
   - Check that `third_party/pHash` directory exists

3. **"WITH_VIDEO_HASH not found"**
   - Ensure you're using the correct pHash fork with video support
   - Check that `-DWITH_VIDEO_HASH=ON` is passed to cmake

### Runtime Issues

1. **"Must specify either -i (image mode) or -v (video mode)"**
   - Always specify `-i` for images or `-v` for videos
   - The tool requires explicit mode selection

2. **"Library not found"**
   - Use `ldd build/phash-compare` to check library dependencies
   - Install missing libraries or adjust LD_LIBRARY_PATH

3. **"Permission denied"**
   - Make sure the build script is executable: `chmod +x build.sh`

## Development

### Adding the Submodule

If you're setting up the project from scratch:

```bash
git submodule add https://github.com/Lord-Evil/pHash.git third_party/pHash
git submodule update --init --recursive
```

### Updating pHash

To update to the latest pHash version:

```bash
git submodule update --remote third_party/pHash
git add third_party/pHash
git commit -m "Update pHash submodule"
```

## License

This project uses the pHash library which is licensed under GPL-3.0. See the [pHash repository](https://github.com/Lord-Evil/pHash) for details. 