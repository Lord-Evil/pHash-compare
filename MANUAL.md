# pHash Compare Tool Manual

## Overview

The `phash-compare` tool uses perceptual hashing to detect duplicate or similar videos and images. It can efficiently handle large collections by caching computed hashes in a database file and supports both video and image processing modes.

## Features

- **Perceptual Hashing**: Uses pHash library to generate video and image fingerprints that are robust against encoding differences
- **Hash Caching**: Stores computed hashes in a database file to avoid re-computation
- **Flexible Comparison**: Compare files with configurable similarity thresholds
- **Multiple Workflows**: Support for different usage patterns from simple comparison to batch processing
- **Multithreading**: Parallel hash computation for faster processing
- **Recursive Search**: Automatically find files in directories and subdirectories
- **File Type Filtering**: Filter by file extensions
- **Stdin Support**: Read file lists from standard input
- **Dual Mode**: Support for both video and image hashing with explicit mode selection

## Installation

### Prerequisites
- `libpHash` library (built as static library)
- `ffmpeg` and related libraries
- C++ compiler with C++17 support

### Compilation
```bash
# Using CMake (recommended)
./build.sh
# or for Gentoo
./build_gentoo.sh

```

**Note**: The CMake build system creates a statically linked executable that includes the pHash library, making it more portable and avoiding runtime library loading issues.

## Usage

### Basic Syntax
```bash
./phash-compare [options] [files...]
```

### Options

- `-d threshold`: Only show files with Hamming distance ≤ threshold
- `-s source_file`: Load existing hashes from database file
- `-w`: Write new hashes to database file
- `-g`: Generate hashes only (no comparison, automatically saves hashes)
- `-j jobs`: Number of parallel jobs for hash computation (default: 1)
- `-i`: Image hash mode (must specify either -i or -v)
- `-v`: Video hash mode (must specify either -i or -v)
- `-r directory`: Recursively search directory for files (can be used multiple times)
- `-t extension`: Filter by file extension (can be used multiple times, case-insensitive)

**Note**: You must specify either `-i` (image mode) or `-v` (video mode) - the tool will not work without one of these flags.

## Complete Usage Patterns

### 1. Generate Hashes Only (`-g` flag)
```bash
./phash-compare -i -g -s hashes.db *.jpg
./phash-compare -v -g -s hashes.db *.mp4
```
**Use case**: Build up a database of hashes over time
- Computes hashes for new files (skips files already in database)
- Automatically saves them to database (no need for `-w`)
- **No comparisons** - very fast for building up the database
- Perfect for batch processing or when you want to separate hash computation from comparison
- **Note**: Requires `-s` flag (will exit with error if not provided)
- **Efficient**: Only processes files that don't already have hashes stored

### 2. Generate + Compare + Save (Most Common)
```bash
./phash-compare -i -s hashes.db -w *.jpg
./phash-compare -v -s hashes.db -w *.mp4
```
**Use case**: Regular duplicate detection workflow
- Loads existing hashes from database
- Computes hashes for new files
- Compares all files (existing + new)
- Saves new hashes to database
- Outputs duplicate pairs for removal

### 3. Compare Existing Files Only (Fast)
```bash
./phash-compare -i -s hashes.db
./phash-compare -v -s hashes.db
```
**Use case**: Quick duplicate check on already processed files
- Only uses hashes already in database
- No new hash computation
- Very fast for large collections
- Useful for periodic duplicate checks
- **Note**: When only `-s` is specified (no input files, no `-r` directories), the tool automatically compares all hashes in the database

### 4. Compare Without Saving (Temporary)
```bash
./phash-compare -i -s hashes.db *.jpg
./phash-compare -v -s hashes.db *.mp4
```
**Use case**: Testing or temporary analysis
- Loads existing hashes
- Computes hashes for new files
- Compares all files
- **Doesn't save** new hashes (useful for testing)

### 5. With Threshold Filtering
```bash
./phash-compare -i -d 3 -s hashes.db -w *.jpg
./phash-compare -v -d 5 -s hashes.db -w *.mp4
```
**Use case**: Duplicate detection with similarity threshold
- Only shows files with distance ≤ threshold
- Perfect for duplicate detection
- Lower threshold = more strict matching
- Higher threshold = more lenient matching

### 6. Parallel Processing
```bash
./phash-compare -i -j 12 -s hashes.db -w *.jpg
./phash-compare -v -j 12 -s hashes.db -w *.mp4
```
**Use case**: Fast processing on multi-core systems
- Uses 12 parallel threads for hash computation
- Significantly faster on multi-core CPUs
- Recommended: use number of CPU cores available
- Only affects hash computation, not comparison phase

### 7. Recursive Directory Search
```bash
./phash-compare -v -r ./videos -r ./backup -t mp4 -t webm -s hashes.db -w
./phash-compare -i -r ./photos -r ./screenshots -t jpg -t png -s image_hashes.db -w
```
**Use case**: Process files scattered across multiple directories
- Recursively searches specified directories
- Only processes files with specified extensions
- Automatically finds all matching files in subdirectories
- Perfect for large, disorganized collections

### 8. Image Hash Mode
```bash
./phash-compare -i -r ./photos -t jpg -t png -t bmp -s image_hashes.db -w
```
**Use case**: Find duplicate or similar images
- Uses image perceptual hashing instead of video hashing
- Processes common image formats (jpg, png, bmp, etc.)
- Much faster than video hashing
- Perfect for photo collections

### 9. Video Hash Mode
```bash
./phash-compare -v -r ./videos -t mp4 -t webm -t avi -s video_hashes.db -w
```
**Use case**: Find duplicate or similar videos
- Uses video perceptual hashing for temporal analysis
- Processes video formats (mp4, webm, avi, etc.)
- More accurate for video content
- Handles encoding differences and quality variations

### 10. Stdin File List
```bash
find . -name "*.jpg" | ./phash-compare -i -s hashes.db -w -
find . -name "*.mp4" | ./phash-compare -v -s hashes.db -w -
```
**Use case**: Use external tools to generate file lists
- Reads file paths from standard input when `-` is specified as an argument
- Works with `find`, `ls`, or any command that outputs file paths
- One file path per line
- Useful for complex file selection logic
- **Note**: Use `-` as a special argument to explicitly read from stdin

### 11. Combined Advanced Usage
```bash
./phash-compare -i -j 12 -r ./photos -t jpg -t png -d 3 -s image_hashes.db -w
./phash-compare -v -j 8 -r ./videos -t mp4 -t webm -d 5 -s video_hashes.db -w
```
**Use case**: High-performance duplicate detection
- Multiple parallel threads for fast processing
- Recursive search in multiple directories
- File type filtering
- Strict threshold for precise matching
- Saves hashes to database 
```
## Database File Format

The hash database uses a simple text format:
```
filename|hash_length|hex_hash_data
```

Example:
```
video1.mp4|3|0000000000000001 0000000000000002 0000000000000003
image1.jpg|1|0000000000000004
video2.mp4|3|0000000000000005 0000000000000006 0000000000000007
```

**Note**: Image hashes always have length 1, while video hashes typically have length 3 or more.

## Output Format

The tool outputs comparison results in the format:
```
distance - file1 - file2
```

Example:
```
2 - video1.mp4 - video2.mp4
5 - image1.jpg - image2.jpg
```

Results are grouped by the first file and sorted by distance (ascending).

## Integration with Bash Scripts

### Example: Automatic Duplicate Removal
```bash
#!/bin/bash
hash_db="video_hashes.db"

# Generate hashes and find duplicates
./phash-compare -v -d 5 -s "$hash_db" -w *.mp4 | while read -r line; do
    # Extract the second filename (the duplicate to remove)
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate: $dupfile"
        rm -- "$dupfile"
    fi
done
```

### Example: Batch Processing with Recursive Search
```bash
#!/bin/bash
hash_db="video_hashes.db"

# Phase 1: Generate hashes for new videos in multiple directories
echo "Generating hashes..."
./phash-compare -v -j 12 -r ./videos -r ./backup -t mp4 -t webm -s "$hash_db" -g

# Phase 2: Compare and find duplicates
echo "Finding duplicates..."
./phash-compare -v -d 5 -s "$hash_db" | while read -r line; do
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate: $dupfile"
        rm -- "$dupfile"
    fi
done
```

### Example: Image Duplicate Detection
```bash
#!/bin/bash
image_db="image_hashes.db"

# Find duplicate images
./phash-compare -i -j 8 -r ./photos -t jpg -t png -t bmp -d 3 -s "$image_db" -w | while read -r line; do
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate image: $dupfile"
        rm -- "$dupfile"
    fi
done
```

## Performance Considerations

### Hash Computation
- **First run**: Computes hashes for all files (slow but necessary)
- **Subsequent runs**: Only computes hashes for new files (fast)
- **Database-only comparison**: No hash computation (very fast)
- **Generate-only mode (-g)**: Only computes hashes for files not in database (very efficient)
- **Parallel processing (-j)**: Use multiple CPU cores for hash computation (much faster)

### Multithreading
- **Hash computation**: Fully parallelized with `-j` flag
- **Comparison phase**: Single-threaded (usually fast enough)
- **Database operations**: Thread-safe with proper synchronization
- **Optimal settings**: Use `-j` equal to number of CPU cores
- **Memory usage**: Increases with number of threads (each thread needs memory for file processing)

### Memory Usage
- Hashes are loaded into memory for comparison
- Large databases may require significant RAM
- Consider processing in batches for very large collections
- Parallel processing increases memory usage proportionally to number of threads

### Video vs Image Hashing
- **Video hashing (-v)**: Slower, more complex, handles temporal information
- **Image hashing (-i)**: Much faster, simpler, single-frame analysis
- **Memory usage**: Video hashing uses more memory per file
- **Accuracy**: Video hashing better for detecting duplicate videos with different encoding

### Threshold Selection
- **Distance 0-2**: Nearly identical files
- **Distance 3-5**: Very similar files (recommended for duplicates)
- **Distance 6-10**: Moderately similar files
- **Distance >10**: Different files
- **Images**: Lower thresholds (1-3) often work better than videos

## Troubleshooting

### Common Issues

1. **"Failed to compute hash"**
   - Check if file is corrupted
   - Ensure ffmpeg can read the video format (for video mode)
   - Verify file permissions
   - For images, ensure format is supported by pHash

2. **"No source file provided"**
   - Use `-s filename` to specify database file
   - Create empty file if it doesn't exist

3. **"No input files specified"**
   - Provide file paths as arguments
   - Use `-r directory` for recursive search
   - Pipe file list to stdin

4. **"Must specify either -i (image mode) or -v (video mode)"**
   - Always specify `-i` for images or `-v` for videos
   - The tool requires explicit mode selection

5. **High memory usage**
   - Process files in smaller batches
   - Use `-g` flag to separate hash generation from comparison
   - Reduce number of parallel jobs with `-j`

6. **Slow performance**
   - Use `-j` flag with number of CPU cores
   - Use `-g` to separate hash generation from comparison
   - For images, use `-i` flag (much faster than video mode)

### Debug Output
The tool provides verbose output showing:
- Number of files found
- Number of hashes loaded from database
- Hash computation progress
- Database save operations
- File processing mode (video vs image)

## Technical Details

### Perceptual Hashing
- **Video mode (-v)**: Uses pHash's `ph_dct_videohash()` function
- **Image mode (-i)**: Uses pHash's `ph_dct_imagehash()` function
- Generates 64-bit hash values for video frames or images
- Robust against encoding differences, resolution changes, and minor quality variations

### Hamming Distance
- Measures bit differences between hash values
- Lower distance = more similar files
- Threshold of 5 is recommended for duplicate detection
- Images often work better with lower thresholds (1-3)

### File Format Support
- **Video mode (-v)**: Primarily MP4, but works with other formats supported by ffmpeg
- **Image mode (-i)**: JPG, PNG, BMP, and other formats supported by pHash
- **Recursive search**: Works with any file system accessible by std::filesystem

### Thread Safety
- All database operations are thread-safe
- File I/O is protected with mutexes
- Hash computation is fully parallelized
- Results collection is thread-safe 