#!/bin/sh
# This one is all on thomas, he is responsible for any bad behavior caused by this script.

$HOME/clang-llvm/build/bin/clang -Xclang -load -Xclang $HOME/clang-llvm/build/lib/DetectPtrCasts.so -Xclang -add-plugin -Xclang detect-ptr-casts casts.cpp
