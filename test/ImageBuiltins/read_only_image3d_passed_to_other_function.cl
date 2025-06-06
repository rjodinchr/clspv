// RUN: clspv %target %s -o %t.spv -no-inline-single
// RUN: spirv-dis -o %t2.spvasm %t.spv
// RUN: FileCheck %s < %t2.spvasm
// RUN: spirv-val --target-env vulkan1.0 %t.spv

const sampler_t s = CLK_NORMALIZED_COORDS_TRUE;

__attribute__((noinline))
float4 bar(read_only image3d_t i, float4 c)
{
  return read_imagef(i, s, c);
}

void kernel __attribute__((reqd_work_group_size(1, 1, 1))) foo(read_only image3d_t i, float4 c, global float4* a)
{
  *a = bar(i, c);
}
// CHECK-DAG:  [[_float:%[0-9a-zA-Z_]+]] = OpTypeFloat 32
// CHECK-DAG:  [[_2:%[0-9a-zA-Z_]+]] = OpTypeSampler
// CHECK-DAG:  [[_4:%[0-9a-zA-Z_]+]] = OpTypeImage [[_float]] 3D 0 0 0 1 Unknown
// CHECK-DAG:  [[_v4float:%[0-9a-zA-Z_]+]] = OpTypeVector [[_float]] 4
// CHECK-DAG:  [[_17:%[0-9a-zA-Z_]+]] = OpTypeSampledImage [[_4]]
// CHECK-DAG:  [[_float_0:%[0-9a-zA-Z_]+]] = OpConstant [[_float]] 0
// CHECK:  = OpFunction
// CHECK:  [[_40:%[0-9a-zA-Z_]+]] = OpFunctionCall [[_v4float]] [[_24:%[0-9a-zA-Z_]+]]
// CHECK:  OpStore {{.*}} [[_40]]
// CHECK:  [[_24]] = OpFunction [[_v4float]]
// CHECK:  [[_27:%[0-9a-zA-Z_]+]] = OpFunctionParameter [[_v4float]]
// CHECK:  [[_28:%[0-9a-zA-Z_]+]] = OpLabel
// CHECK:  [[_29:%[0-9a-zA-Z_]+]] = OpLoad [[_4]]
// CHECK:  [[_30:%[0-9a-zA-Z_]+]] = OpLoad [[_2]]
// CHECK:  [[_31:%[0-9a-zA-Z_]+]] = OpSampledImage [[_17]] [[_29]] [[_30]]

// CHECK:  [[_32:%[0-9a-zA-Z_]+]] = OpImageSampleExplicitLod [[_v4float]] [[_31]] [[_27]] Lod [[_float_0]]
// CHECK:  OpReturnValue [[_32]]
