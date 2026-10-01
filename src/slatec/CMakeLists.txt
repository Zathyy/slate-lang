cmake_minimum_required(VERSION 3.25)
project(slatec CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

file(GLOB_RECURSE SLATEC_SOURCES
        CONFIGURE_DEPENDS
        src/*.cpp
        src/*.h
)

add_executable(slatec ${SLATEC_SOURCES})

target_include_directories(slatec PUBLIC src)
