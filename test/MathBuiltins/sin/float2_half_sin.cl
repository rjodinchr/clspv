// RUN: clspv %target %s -o %t.spv -no-inline-single
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

// CHECK-DAG: %[[FLOAT_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeFloat 32
// CHECK-DAG: %[[FLOAT_VECTOR_TYPE_ID:[a-zA-Z0-9_]*]] = OpTypeVector %[[FLOAT_TYPE_ID]] 2
// CHECK: %[[LOADB_ID:[a-zA-Z0-9_]*]] = OpLoad %[[FLOAT_VECTOR_TYPE_ID]]
// CHECK: %[[OP_0:[a-zA-Z0-9_]*]] = OpFunctionCall %[[FLOAT_VECTOR_TYPE_ID]] %{{.*}} %[[LOADB_ID]]
// CHECK: OpStore {{.*}} %[[OP_0]]

void kernel __attribute__((reqd_work_group_size(1, 1, 1))) foo(global float2* a, global float2* b)
{
  *a = half_sin(*b);
}
