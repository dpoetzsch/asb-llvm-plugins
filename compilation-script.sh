#!/bin/sh

clang -Xclang -load -Xclang /home/thomas/clang-llvm/build/lib/DetectPtrCasts.so -Xclang -add-plugin -Xclang detect-ptr-casts casts.cpp
