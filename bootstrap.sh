#!/bin/sh

CMAKE_FILE=../CMakeLists.txt

echo >> $CMAKE_FILE
echo "# Build the plugins handling address sensitive behavior" >> $CMAKE_FILE
echo "add_subdirectory(asb-examples)" >> $CMAKE_FILE
