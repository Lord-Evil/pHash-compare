# pHash Video Comparison Tool Manual

## Overview

The `phash_video_compare` tool uses perceptual hashing to detect duplicate or similar videos. It can efficiently handle large video collections by caching computed hashes in a database file.

## Features

- **Perceptual Hashing**: Uses pHash library to generate video fingerprints that are robust against encoding differences
- **Hash Caching**: Stores computed hashes in a database file to avoid re-computation
- **Flexible Comparison**: Compare videos with configurable similarity thresholds
- **Multiple Workflows**: Support for different usage patterns from simple comparison to batch processing

## Installation

### Prerequisites
- `libpHash` library (built as static library)
- `ffmpeg` and related libraries
- C++ compiler with C++11 support

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
./phash_video_compare [options] [video_files...]
```

### Options

- `-d threshold`: Only show videos with Hamming distance ≤ threshold
- `-s source_file`: Load existing hashes from database file
- `-w`: Write new hashes to database file
- `-g`: Generate hashes only (no comparison, automatically saves hashes)
- `-j jobs`: Number of parallel jobs for hash computation (default: 1)

## Complete Usage Patterns

### 1. Generate Hashes Only (`-g` flag)
```bash
./phash_video_compare -g -s hashes.db *.mp4
```
**Use case**: Build up a database of hashes over time
- Computes hashes for new videos (skips files already in database)
- Automatically saves them to database (no need for `-w`)
- **No comparisons** - very fast for building up the database
- Perfect for batch processing or when you want to separate hash computation from comparison
- **Note**: Requires `-s` flag (will exit with error if not provided)
- **Efficient**: Only processes files that don't already have hashes stored

### 2. Generate + Compare + Save (Most Common)
```bash
./phash_video_compare -s hashes.db -w *.mp4
```
**Use case**: Regular duplicate detection workflow
- Loads existing hashes from database
- Computes hashes for new videos
- Compares all videos (existing + new)
- Saves new hashes to database
- Outputs duplicate pairs for removal

### 3. Compare Existing Videos Only (Fast)
```bash
./phash_video_compare -s hashes.db
```
**Use case**: Quick duplicate check on already processed videos
- Only uses hashes already in database
- No new hash computation
- Very fast for large collections
- Useful for periodic duplicate checks

### 4. Compare Without Saving (Temporary)
```bash
./phash_video_compare -s hashes.db *.mp4
```
**Use case**: Testing or temporary analysis
- Loads existing hashes
- Computes hashes for new videos
- Compares all videos
- **Doesn't save** new hashes (useful for testing)

### 5. With Threshold Filtering
```bash
./phash_video_compare -d 5 -s hashes.db -w *.mp4
```
**Use case**: Duplicate detection with similarity threshold
- Only shows videos with distance ≤ 5
- Perfect for duplicate detection
- Lower threshold = more strict matching
- Higher threshold = more lenient matching

### 6. Parallel Processing
```bash
./phash_video_compare -j 12 -s hashes.db -w *.mp4
```
**Use case**: Fast processing on multi-core systems
- Uses 12 parallel threads for hash computation
- Significantly faster on multi-core CPUs
- Recommended: use number of CPU cores available
- Only affects hash computation, not comparison phase

## Database File Format

The hash database uses a simple text format:
```
filename|hash_length|hex_hash_data
```

Example:
```
video1.mp4|3|0000000000000001 0000000000000002 0000000000000003
video2.mp4|3|0000000000000004 0000000000000005 0000000000000006
```

## Output Format

The tool outputs comparison results in the format:
```
distance - file1 - file2
```

Example:
```
2 - video1.mp4 - video2.mp4
5 - video3.mp4 - video4.mp4
```

## Integration with Bash Scripts

### Example: Automatic Duplicate Removal
```bash
#!/bin/bash
hash_db="video_hashes.db"

# Generate hashes and find duplicates
./phash_video_compare -d 5 -s "$hash_db" -w *.mp4 | while read -r line; do
    # Extract the second filename (the duplicate to remove)
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate: $dupfile"
        rm -- "$dupfile"
    fi
done
```

### Example: Batch Processing
```bash
#!/bin/bash
hash_db="video_hashes.db"

# Phase 1: Generate hashes for new videos
echo "Generating hashes..."
./phash_video_compare -s "$hash_db" -g *.mp4

# Phase 2: Compare and find duplicates
echo "Finding duplicates..."
./phash_video_compare -d 5 -s "$hash_db" | while read -r line; do
    dupfile=$(echo "$line" | awk -F' - ' '{print $3}')
    if [ -f "$dupfile" ]; then
        echo "Removing duplicate: $dupfile"
        rm -- "$dupfile"
    fi
done
```

## Performance Considerations

### Hash Computation
- **First run**: Computes hashes for all videos (slow but necessary)
- **Subsequent runs**: Only computes hashes for new videos (fast)
- **Database-only comparison**: No hash computation (very fast)
- **Generate-only mode (-g)**: Only computes hashes for files not in database (very efficient)
- **Parallel processing (-j)**: Use multiple CPU cores for hash computation (much faster)

### Multithreading
- **Hash computation**: Fully parallelized with `-j` flag
- **Comparison phase**: Single-threaded (usually fast enough)
- **Database operations**: Thread-safe with proper synchronization
- **Optimal settings**: Use `-j` equal to number of CPU cores
- **Memory usage**: Increases with number of threads (each thread needs memory for video processing)

### Memory Usage
- Hashes are loaded into memory for comparison
- Large databases may require significant RAM
- Consider processing in batches for very large collections
- Parallel processing increases memory usage proportionally to number of threads

### Threshold Selection
- **Distance 0-2**: Nearly identical videos
- **Distance 3-5**: Very similar videos (recommended for duplicates)
- **Distance 6-10**: Moderately similar videos
- **Distance >10**: Different videos

## Troubleshooting

### Common Issues

1. **"Failed to compute hash"**
   - Check if video file is corrupted
   - Ensure ffmpeg can read the video format
   - Verify file permissions

2. **"No source file provided"**
   - Use `-s filename` to specify database file
   - Create empty file if it doesn't exist

3. **High memory usage**
   - Process videos in smaller batches
   - Use `-g` flag to separate hash generation from comparison

### Debug Output
The tool provides verbose output showing:
- Number of hashes loaded from database
- Hash computation progress
- Database save operations

## Technical Details

### Perceptual Hashing
- Uses pHash's `ph_dct_videohash()` function
- Generates 64-bit hash values for video frames
- Robust against encoding differences, resolution changes, and minor quality variations

### Hamming Distance
- Measures bit differences between hash values
- Lower distance = more similar videos
- Threshold of 5 is recommended for duplicate detection

### File Format Support
- Primarily designed for MP4 files
- May work with other formats supported by ffmpeg
- Requires video and audio streams for proper hashing 