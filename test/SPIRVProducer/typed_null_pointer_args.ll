; RUN: clspv-opt %s -o %t.ll --passes=spirv-producer -producer-out-file %t.spv
; RUN: spirv-dis %t.spv -o %t.spvasm
; RUN: FileCheck %s < %t.spvasm
; RUN: spirv-val --target-env vulkan1.0 %t.spv

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

@__spirv_WorkgroupSize = local_unnamed_addr addrspace(8) global <3 x i32> zeroinitializer

; CHECK-DAG: %[[NULL_INT:[a-zA-Z0-9_]+]] = OpConstantNull %_ptr_StorageBuffer_uint
; CHECK-DAG: %[[NULL_FLOAT:[a-zA-Z0-9_]+]] = OpConstantNull %_ptr_StorageBuffer_float
; CHECK: OpLoad %uint %[[NULL_INT]]
; CHECK: OpLoad %float %[[NULL_FLOAT]]

define spir_kernel void @foo(ptr addrspace(1) %out, ptr addrspace(1) %in, { i32 } %podargs) !clspv.pod_args_impl !0 !kernel_arg_map !1 {
entry:
  %res0 = call ptr addrspace(1) @_Z14clspv.resource.0(i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, { [0 x i32] } zeroinitializer)
  %gep0 = getelementptr { [0 x i32] }, ptr addrspace(1) %res0, i32 0, i32 0, i32 0
  %res1 = call ptr addrspace(1) @_Z14clspv.resource.1(i32 0, i32 1, i32 0, i32 1, i32 1, i32 0, { [0 x i32] } zeroinitializer)
  %gep1 = getelementptr { [0 x i32] }, ptr addrspace(1) %res1, i32 0, i32 0, i32 0
  %res2 = call ptr addrspace(9) @_Z14clspv.resource.2(i32 -1, i32 2, i32 5, i32 2, i32 2, i32 0, { { i32 } } zeroinitializer)
  %gep2 = getelementptr { { i32 } }, ptr addrspace(9) %res2, i32 0, i32 0
  %ld = load { i32 }, ptr addrspace(9) %gep2, align 4
  %cond = extractvalue { i32 } %ld, 0
  %cmp = icmp ne i32 %cond, 0
  %sel = select i1 %cmp, ptr addrspace(1) %gep0, ptr addrspace(1) %gep1
  br i1 %cmp, label %then, label %exit

then:
  %v1 = load volatile i32, ptr addrspace(1) null, align 4
  %v2 = load volatile float, ptr addrspace(1) null, align 4
  %v2i = fptosi float %v2 to i32
  %sum = add i32 %v1, %v2i
  store i32 %sum, ptr addrspace(1) %sel, align 4
  br label %exit

exit:
  ret void
}

declare ptr addrspace(1) @_Z14clspv.resource.0(i32, i32, i32, i32, i32, i32, { [0 x i32] })
declare ptr addrspace(1) @_Z14clspv.resource.1(i32, i32, i32, i32, i32, i32, { [0 x i32] })
declare ptr addrspace(9) @_Z14clspv.resource.2(i32, i32, i32, i32, i32, i32, { { i32 } })

!0 = !{i32 2}
!1 = !{!2, !3, !4}
!2 = !{!"out", i32 0, i32 0, i32 0, i32 0, !"buffer"}
!3 = !{!"in", i32 1, i32 1, i32 0, i32 0, !"buffer"}
!4 = !{!"cond", i32 2, i32 2, i32 0, i32 4, !"pod_pushconstant"}
