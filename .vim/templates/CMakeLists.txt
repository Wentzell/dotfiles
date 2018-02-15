# Version number of TRILEX 
set (Test_VERSION "1.5")

# Start configuration
cmake_minimum_required(VERSION 2.8)

# Load TRIQS
find_package(TRIQS 1.5 EXACT REQUIRED)
find_package(Cpp2Py REQUIRED)
add_executable(Test main.cpp)
target_link_libraries(Test PUBLIC triqs gtest)
target_compile_options(Test PUBLIC -std=c++17)
