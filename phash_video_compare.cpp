#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <cstdlib>
#include <pHash.h>
#include <set>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <map>
#include <unistd.h>
#include <thread>
#include <mutex>
#include <queue>
#include <condition_variable>
#include <algorithm>

struct VideoHash {
    std::string filename;
    ulong64* hash;
    int length;
    VideoHash(const std::string& f, ulong64* h, int l) : filename(f), hash(h), length(l) {}
};

// Thread-safe queue for work distribution
template<typename T>
class ThreadSafeQueue {
private:
    std::queue<T> queue;
    mutable std::mutex mutex;
    std::condition_variable condition;

public:
    void push(T value) {
        std::lock_guard<std::mutex> lock(mutex);
        queue.push(std::move(value));
        condition.notify_one();
    }

    bool pop(T& value) {
        std::unique_lock<std::mutex> lock(mutex);
        if (queue.empty()) {
            return false;
        }
        value = std::move(queue.front());
        queue.pop();
        return true;
    }

    bool wait_and_pop(T& value) {
        std::unique_lock<std::mutex> lock(mutex);
        condition.wait(lock, [this] { return !queue.empty(); });
        value = std::move(queue.front());
        queue.pop();
        return true;
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex);
        return queue.empty();
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex);
        return queue.size();
    }
};

// Thread-safe vector for results
template<typename T>
class ThreadSafeVector {
private:
    std::vector<T> vector;
    mutable std::mutex mutex;

public:
    void push_back(T value) {
        std::lock_guard<std::mutex> lock(mutex);
        vector.push_back(std::move(value));
    }

    std::vector<T> get_all() const {
        std::lock_guard<std::mutex> lock(mutex);
        return vector;
    }

    size_t size() const {
        std::lock_guard<std::mutex> lock(mutex);
        return vector.size();
    }
};

// Helper to compute Hamming distance between two 64-bit hashes
int hamming_distance(ulong64* hash1, int len1, ulong64* hash2, int len2) {
    int minlen = std::min(len1, len2);
    int dist = 0;
    for (int i = 0; i < minlen; ++i) {
        dist += ph_hamming_distance(hash1[i], hash2[i]);
    }
    // If lengths differ, count extra blocks as max distance
    dist += 64 * std::abs(len1 - len2);
    return dist;
}

// Convert hash array to hex string
std::string hash_to_hex(ulong64* hash, int length) {
    std::stringstream ss;
    for (int i = 0; i < length; ++i) {
        if (i > 0) ss << " ";
        ss << std::hex << std::setw(16) << std::setfill('0') << hash[i];
    }
    return ss.str();
}

// Convert hex string back to hash array
ulong64* hex_to_hash(const std::string& hex_str, int& length) {
    std::stringstream ss(hex_str);
    std::vector<ulong64> hash_vec;
    ulong64 hash_val;
    
    while (ss >> std::hex >> hash_val) {
        hash_vec.push_back(hash_val);
    }
    
    length = hash_vec.size();
    if (length == 0) return nullptr;
    
    ulong64* hash = (ulong64*)malloc(length * sizeof(ulong64));
    for (int i = 0; i < length; ++i) {
        hash[i] = hash_vec[i];
    }
    return hash;
}

// Load hashes from file
std::map<std::string, std::pair<ulong64*, int>> load_hashes(const std::string& filename) {
    std::map<std::string, std::pair<ulong64*, int>> hash_map;
    std::ifstream file(filename);
    std::string line;
    
    while (std::getline(file, line)) {
        size_t pos1 = line.find('|');
        if (pos1 == std::string::npos) continue;
        
        size_t pos2 = line.find('|', pos1 + 1);
        if (pos2 == std::string::npos) continue;
        
        std::string filepath = line.substr(0, pos1);
        int length = std::stoi(line.substr(pos1 + 1, pos2 - pos1 - 1));
        std::string hex_hash = line.substr(pos2 + 1);
        
        int loaded_length;
        ulong64* hash = hex_to_hash(hex_hash, loaded_length);
        if (hash && loaded_length == length) {
            hash_map[filepath] = {hash, length};
        }
    }
    
    return hash_map;
}

// Save hashes to file (thread-safe)
void save_hashes(const std::string& filename, const std::vector<VideoHash>& hashes) {
    static std::mutex save_mutex;
    std::lock_guard<std::mutex> lock(save_mutex);
    
    std::ofstream file(filename, std::ios::app);
    for (const auto& vh : hashes) {
        file << vh.filename << "|" << vh.length << "|" << hash_to_hex(vh.hash, vh.length) << std::endl;
    }
}

// Worker thread function
void hash_worker(ThreadSafeQueue<std::string>& work_queue, 
                 ThreadSafeVector<VideoHash>& results,
                 std::mutex& cerr_mutex) {
    std::string filename;
    while (work_queue.pop(filename)) {
        int length = 0;
        ulong64* hash = ph_dct_videohash(filename.c_str(), length);
        if (!hash || length == 0) {
            std::lock_guard<std::mutex> lock(cerr_mutex);
            std::cerr << "Failed to compute hash for " << filename << std::endl;
            continue;
        }
        
        results.push_back(VideoHash(filename, hash, length));
        
        std::lock_guard<std::mutex> lock(cerr_mutex);
        std::cerr << "Computed hash for " << filename << std::endl;
    }
}

int main(int argc, char* argv[]) {
    int threshold = -1; // -1 means print all
    std::string source_file;
    bool write_hashes = false;
    bool generate_only = false;
    int num_jobs = 1; // Default to single-threaded
    int opt;

    // Parse command line arguments using getopt
    while ((opt = getopt(argc, argv, "d:s:wgj:")) != -1) {
        switch (opt) {
            case 'd':
                threshold = std::atoi(optarg);
                if (threshold < 0) {
                    std::cerr << "Threshold must be a positive integer" << std::endl;
                    return 1;
                }
                break;
            case 's':
                source_file = optarg;
                break;
            case 'w':
                write_hashes = true;
                break;
            case 'g':
                generate_only = true;
                write_hashes = true; // -g implies -w
                break;
            case 'j':
                num_jobs = std::atoi(optarg);
                if (num_jobs <= 0) {
                    std::cerr << "Number of jobs must be positive" << std::endl;
                    return 1;
                }
                break;
            case '?':
                std::cerr << "Usage: " << argv[0] << " [-d threshold] [-s source_file] [-w] [-g] [-j jobs] [video1 video2 ...]" << std::endl;
                std::cerr << "  -d threshold: only show videos with distance <= threshold" << std::endl;
                std::cerr << "  -s source_file: load existing hashes from file" << std::endl;
                std::cerr << "  -w: write new hashes to source file" << std::endl;
                std::cerr << "  -g: generate hashes only (no comparison, implies -w)" << std::endl;
                std::cerr << "  -j jobs: number of parallel jobs (default: 1)" << std::endl;
                std::cerr << "  If no video files provided, only compare hashes in database" << std::endl;
                return 1;
            default:
                std::cerr << "Usage: " << argv[0] << " [-d threshold] [-s source_file] [-w] [-g] [-j jobs] [video1 video2 ...]" << std::endl;
                return 1;
        }
    }

    // Early exit if -g specified without source file
    if (generate_only && source_file.empty()) {
        std::cerr << "Error: -g specified but no source file (-s) provided. Cannot save hashes." << std::endl;
        return 1;
    }

    // Load existing hashes if source file provided
    std::map<std::string, std::pair<ulong64*, int>> existing_hashes;
    if (!source_file.empty()) {
        existing_hashes = load_hashes(source_file);
        std::cerr << "Loaded " << existing_hashes.size() << " existing hashes from " << source_file << std::endl;
    }

    std::vector<VideoHash> hashes;
    
    // If no video files provided, only use existing hashes from database
    if (optind >= argc) {
        if (source_file.empty()) {
            std::cerr << "Error: No source file (-s) provided and no video files specified" << std::endl;
            return 1;
        }
        // Load all existing hashes into the comparison vector
        for (const auto& pair : existing_hashes) {
            hashes.emplace_back(pair.first, pair.second.first, pair.second.second);
        }
        std::cerr << "Comparing " << hashes.size() << " videos from database only" << std::endl;
    } else {
        // Collect files that need hash computation
        std::vector<std::string> files_to_process;
        for (int i = optind; i < argc; ++i) {
            auto it = existing_hashes.find(argv[i]);
            if (it != existing_hashes.end()) {
                hashes.emplace_back(argv[i], it->second.first, it->second.second);
                std::cerr << "Loaded hash for " << argv[i] << std::endl;
            } else {
                files_to_process.push_back(argv[i]);
            }
        }

        // Process files that need hash computation (with multithreading if requested)
        if (!files_to_process.empty()) {
            if (num_jobs > 1 && files_to_process.size() > 1) {
                // Multi-threaded processing
                std::cerr << "Processing " << files_to_process.size() << " files with " << num_jobs << " threads..." << std::endl;
                
                ThreadSafeQueue<std::string> work_queue;
                ThreadSafeVector<VideoHash> thread_results;
                std::mutex cerr_mutex;
                
                // Add work to queue
                for (const auto& file : files_to_process) {
                    work_queue.push(file);
                }
                
                // Start worker threads
                std::vector<std::thread> threads;
                for (int i = 0; i < num_jobs; ++i) {
                    threads.emplace_back(hash_worker, std::ref(work_queue), std::ref(thread_results), std::ref(cerr_mutex));
                }
                
                // Wait for all threads to complete
                for (auto& thread : threads) {
                    thread.join();
                }
                
                // Collect results
                auto thread_hashes = thread_results.get_all();
                hashes.insert(hashes.end(), thread_hashes.begin(), thread_hashes.end());
                
            } else {
                // Single-threaded processing
                for (const auto& file : files_to_process) {
                    int length = 0;
                    ulong64* hash = ph_dct_videohash(file.c_str(), length);
                    if (!hash || length == 0) {
                        std::cerr << "Failed to compute hash for " << file << std::endl;
                        continue;
                    }
                    hashes.emplace_back(file, hash, length);
                    std::cerr << "Computed hash for " << file << std::endl;
                }
            }
        }
    }

    // If generate-only mode, just save hashes and exit
    if (generate_only) {
        // Only save hashes for files that were newly computed (not loaded from database)
        std::vector<VideoHash> new_hashes;
        for (const auto& vh : hashes) {
            if (existing_hashes.find(vh.filename) == existing_hashes.end()) {
                new_hashes.push_back(vh);
            }
        }
        
        if (!new_hashes.empty()) {
            save_hashes(source_file, new_hashes);
            std::cerr << "Saved " << new_hashes.size() << " new hashes to " << source_file << std::endl;
        } else {
            std::cerr << "No new hashes to save (all files already in database)" << std::endl;
        }
        
        // Free hashes (only the ones we computed, not loaded ones)
        for (auto& vh : hashes) {
            if (existing_hashes.find(vh.filename) == existing_hashes.end()) {
                free(vh.hash);
            }
        }
        return 0;
    }

    // Compare all pairs and group by first file
    std::map<std::string, std::vector<std::pair<int, std::string>>> grouped_results;
    std::set<std::pair<std::string, std::string>> reported;
    
    for (size_t i = 0; i < hashes.size(); ++i) {
        for (size_t j = i + 1; j < hashes.size(); ++j) {
            int dist = hamming_distance(hashes[i].hash, hashes[i].length, hashes[j].hash, hashes[j].length);
            if (threshold == -1 || dist <= threshold) {
                // Group by first filename and store distance with second filename
                grouped_results[hashes[i].filename].push_back({dist, hashes[j].filename});
                reported.insert({hashes[i].filename, hashes[j].filename});
            }
        }
    }

    // Print grouped and sorted results
    for (const auto& group : grouped_results) {
        const std::string& first_file = group.first;
        const auto& comparisons = group.second;
        
        // Sort comparisons by distance (ascending)
        std::vector<std::pair<int, std::string>> sorted_comparisons = comparisons;
        std::sort(sorted_comparisons.begin(), sorted_comparisons.end());
        
        // Print all comparisons for this first file
        for (const auto& comp : sorted_comparisons) {
            std::cout << comp.first << " - " << first_file << " - " << comp.second << std::endl;
        }
    }

    // Save new hashes if requested
    if (write_hashes && !source_file.empty() && optind < argc) {
        save_hashes(source_file, hashes);
        std::cerr << "Saved hashes to " << source_file << std::endl;
    }

    // Free hashes (only the ones we computed, not loaded ones)
    for (auto& vh : hashes) {
        if (existing_hashes.find(vh.filename) == existing_hashes.end()) {
            free(vh.hash);
        }
    }

    return 0;
} 