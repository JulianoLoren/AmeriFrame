cmake_minimum_required(VERSION 3.22.1)
project(mosaic)
add_library(mosaic SHARED GeometryJNI.cpp ../../../../../core/Geometry.cpp)
target_include_directories(mosaic PRIVATE ../../../../../core)
target_compile_features(mosaic PRIVATE cxx_std_17)
target_compile_options(mosaic PRIVATE -ffp-contract=off -Wall -Wextra)
# Flexible page sizes for devices using 16 KB pages.
target_link_options(mosaic PRIVATE "-Wl,-z,max-page-size=16384")
