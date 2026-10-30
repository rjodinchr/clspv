; RUN: clspv-opt %s -o %t.ll --passes=allocate-descriptors
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

; CHECK: call ptr addrspace(1) @_Z14clspv.resource.0(i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, { [0 x float] } zeroinitializer)

define dso_local spir_func float @read_from_container(ptr %arr, i32 %idx) {
entry:
  %slot = getelementptr [2 x ptr addrspace(1)], ptr %arr, i32 0, i32 %idx
  %ld_ptr = load ptr addrspace(1), ptr %slot, align 4
  %val = load float, ptr addrspace(1) %ld_ptr, align 4
  ret float %val
}

define spir_kernel void @foo(ptr addrspace(1) %buf, ptr addrspace(1) %out, i32 %idx) !clspv.pod_args_impl !0 {
entry:
  %arr = alloca [2 x ptr addrspace(1)], align 4
  %s0 = getelementptr [2 x ptr addrspace(1)], ptr %arr, i32 0, i32 0
  store ptr addrspace(1) %buf, ptr %s0, align 4
  %val = call spir_func float @read_from_container(ptr %arr, i32 %idx)
  store float %val, ptr addrspace(1) %out, align 4
  ret void
}

!0 = !{i32 2}
