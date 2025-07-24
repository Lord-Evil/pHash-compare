cmake_minimum_required(VERSION 3.16)
project(phash-compare VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)

# Find FFmpeg components
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED 
    libavformat 
    libavcodec 
    libswscale 
    libavutil
)

# Find image libraries (optional - video hashing might not need all of them)
find_package(PkgConfig)
set(IMAGE_LIBS_FOUND TRUE)
set(IMAGE_LIBS_LIBRARIES "")
set(IMAGE_LIBS_INCLUDE_DIRS "")
set(IMAGE_LIBS_CFLAGS_OTHER "")
set(IMAGE_LIBS_LDFLAGS_OTHER "")

# Try to find each image library individually
pkg_check_modules(JPEG libjpeg)
if(JPEG_FOUND)
    list(APPEND IMAGE_LIBS_LIBRARIES ${JPEG_LIBRARIES})
    list(APPEND IMAGE_LIBS_INCLUDE_DIRS ${JPEG_INCLUDE_DIRS})
    list(APPEND IMAGE_LIBS_CFLAGS_OTHER ${JPEG_CFLAGS_OTHER})
    list(APPEND IMAGE_LIBS_LDFLAGS_OTHER ${JPEG_LDFLAGS_OTHER})
    message(STATUS "Found libjpeg: ${JPEG_LIBRARIES}")
else()
    message(STATUS "Warning: libjpeg not found - continuing without it")
endif()

pkg_check_modules(PNG libpng)
if(PNG_FOUND)
    list(APPEND IMAGE_LIBS_LIBRARIES ${PNG_LIBRARIES})
    list(APPEND IMAGE_LIBS_INCLUDE_DIRS ${PNG_INCLUDE_DIRS})
    list(APPEND IMAGE_LIBS_CFLAGS_OTHER ${PNG_CFLAGS_OTHER})
    list(APPEND IMAGE_LIBS_LDFLAGS_OTHER ${PNG_LDFLAGS_OTHER})
    message(STATUS "Found libpng: ${PNG_LIBRARIES}")
else()
    message(STATUS "Warning: libpng not found - continuing without it")
endif()

pkg_check_modules(TIFF libtiff-4)
if(TIFF_FOUND)
    list(APPEND IMAGE_LIBS_LIBRARIES ${TIFF_LIBRARIES})
    list(APPEND IMAGE_LIBS_INCLUDE_DIRS ${TIFF_INCLUDE_DIRS})
    list(APPEND IMAGE_LIBS_CFLAGS_OTHER ${TIFF_CFLAGS_OTHER})
    list(APPEND IMAGE_LIBS_LDFLAGS_OTHER ${TIFF_LDFLAGS_OTHER})
    message(STATUS "Found libtiff-4: ${TIFF_LIBRARIES}")
else()
    message(STATUS "Warning: libtiff-4 not found - continuing without it")
endif()

# Add pHash as a subdirectory (submodule) with static library settings
add_subdirectory(third_party/pHash)

# Override pHash build options to use static library and prevent installation
set(PHASH_DYNAMIC OFF CACHE BOOL "Build pHash dynamic library" FORCE)
set(PHASH_STATIC ON CACHE BOOL "Build pHash static library" FORCE)
set(PHASH_INSTALL OFF CACHE BOOL "Install pHash library and headers" FORCE)

# Create the executable
add_executable(phash-compare phash-compare.cpp)

# Link libraries
target_link_libraries(phash-compare
    PRIVATE
    pHash
    Threads::Threads
    ${FFMPEG_LIBRARIES}
    ${IMAGE_LIBS_LIBRARIES}
    m
)

# Include directories
target_include_directories(phash-compare
    PRIVATE
    ${FFMPEG_INCLUDE_DIRS}
    ${IMAGE_LIBS_INCLUDE_DIRS}
    third_party/pHash/src
    third_party/pHash/third-party/CImg
)

# Compiler flags
target_compile_options(phash-compare
    PRIVATE
    ${FFMPEG_CFLAGS_OTHER}
    ${IMAGE_LIBS_CFLAGS_OTHER}
)

# Linker flags
target_link_options(phash-compare
    PRIVATE
    ${FFMPEG_LDFLAGS_OTHER}
    ${IMAGE_LIBS_LDFLAGS_OTHER}
)

# Install target
install(TARGETS phash-compare
    RUNTIME DESTINATION bin
)

# Install man page
install(FILES phash-compare.1
    DESTINATION share/man/man1
)

# Create uninstall target
if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_custom_command(TARGET phash-compare POST_BUILD
        COMMAND ${CMAKE_STRIP} $<TARGET_FILE:phash-compare>
        COMMENT "Stripping phash-compare"
    )
endif() 