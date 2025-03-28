// Test for https://github.com/google/clspv/issues/166
// Function declarations were missing from builtin header.

// RUN: clspv %target %s -o %t.spv --spv-version=1.4
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.2 %t.spv


kernel void foo(global float *A, uint a) {
  *A = as_float(a);
}

// CHECK-DAG: [[int:%[a-zA-Z0-9_]+]] = OpTypeInt 32 0
// CHECK: [[ld:%[a-zA-Z0-9_]+]] = OpCompositeExtract [[int]]
// CHECK: OpStore {{.*}} [[ld]]
