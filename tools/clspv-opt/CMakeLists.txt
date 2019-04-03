# Copyright 2017 The Clspv Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if(NOT ENABLE_CLSPV_OPT)
  return()
endif()

add_executable(clspv-opt ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)

if(APPLE)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} \
    -DLLVM_OPT=\\\"${CLSPV_LLVM_BINARY_DIR}/bin/opt\\\" \
    -DCLSPV_PASSES=\\\"${CLSPV_BINARY_DIR}/lib/libclspv_passes.dylib\\\"")
else()
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} \
    -DLLVM_OPT=\\\"${CLSPV_LLVM_BINARY_DIR}/bin/opt\\\" \
    -DCLSPV_PASSES=\\\"${CLSPV_BINARY_DIR}/lib/libclspv_passes.so\\\"")
endif()

# Enable C++11 for our executable
target_compile_features(clspv-opt PRIVATE cxx_range_for)

target_include_directories(clspv-opt PRIVATE ${CLSPV_INCLUDE_DIRS})
target_include_directories(clspv-opt PRIVATE ${LLVM_INCLUDE_DIRS})

if(${EXTERNAL_LLVM} EQUAL 1)
  include(${CLSPV_LLVM_BINARY_DIR}/lib/cmake/llvm/LLVMConfig.cmake)

  set(CLSPV_LLVM_COMPONENTS LLVMSupport)
  llvm_map_components_to_libnames(CLSPV_LLVM_LINKS ${CLSPV_LLVM_COMPONENTS})

  target_link_libraries(clspv-opt PRIVATE ${CLSPV_LLVM_COMPONENTS})
else()
  target_link_libraries(clspv-opt PRIVATE LLVMSupport)
endif()

set_target_properties(clspv-opt PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CLSPV_BINARY_DIR}/bin)

add_dependencies(clspv-opt clspv_passes opt)