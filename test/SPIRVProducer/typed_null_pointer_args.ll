; RUN: clspv %target -x ir %s -o %t.spv
; RUN: spirv-dis -o %t2.spvasm %t.spv
; RUN: FileCheck %s < %t2.spvasm
; RUN: spirv-val --target-env vulkan1.0 %t.spv

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

; CHECK-DAG: %[[NULL_INT:[a-zA-Z0-9_]+]] = OpConstantNull %_ptr_StorageBuffer_uint
; CHECK-DAG: %[[NULL_FLOAT:[a-zA-Z0-9_]+]] = OpConstantNull %_ptr_StorageBuffer_float
; CHECK: OpLoad %uint %[[NULL_INT]]
; CHECK: OpLoad %float %[[NULL_FLOAT]]

define spir_kernel void @foo(ptr addrspace(1) %out, ptr addrspace(1) %in, i32 %cond) !kernel_arg_addr_space !0 !kernel_arg_access_qual !1 !kernel_arg_type !2 !kernel_arg_base_type !2 !kernel_arg_type_qual !3 {
entry:
  %cmp = icmp ne i32 %cond, 0
  %sel = select i1 %cmp, ptr addrspace(1) %out, ptr addrspace(1) %in
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

!0 = !{i32 1, i32 1, i32 0}
!1 = !{!"none", !"none", !"none"}
!2 = !{!"int*", !"int*", !"int"}
!3 = !{!"", !"", !""}
