; RUN: clspv-opt %s -o %t.ll --passes=direct-resource-access,remove-unused-arguments
; RUN: FileCheck %s < %t.ll

; CHECK-LABEL: define dso_local spir_kernel void @foo(
; CHECK-NOT: alloca [2 x ptr addrspace(1)]
; CHECK: call float @helper(i32 %idx, i32 %elem)

; CHECK-LABEL: define spir_func float @helper(i32 %0, i32 %1)
; CHECK-DAG: %[[RES1:[a-zA-Z0-9_.]+]] = call ptr addrspace(1) @_Z14clspv.resource.1(i32 0, i32 1, i32 0, i32 1, i32 1, i32 0, { [0 x float] } zeroinitializer)
; CHECK-DAG: %[[RES2:[a-zA-Z0-9_.]+]] = call ptr addrspace(1) @_Z14clspv.resource.2(i32 0, i32 2, i32 0, i32 2, i32 2, i32 0, { [0 x float] } zeroinitializer)
; CHECK: %[[CMP:[a-zA-Z0-9_.]+]] = icmp eq i32 %0, 1
; CHECK: %[[SEL:[a-zA-Z0-9_.]+]] = select i1 %[[CMP]], ptr addrspace(1) %[[RES2]], ptr addrspace(1) %[[RES1]]
; CHECK: %[[GEP:[a-zA-Z0-9_.]+]] = getelementptr float, ptr addrspace(1) %[[SEL]], i32 %1
; CHECK: load float, ptr addrspace(1) %[[GEP]], align 4

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

declare ptr addrspace(1) @_Z14clspv.resource.0(i32, i32, i32, i32, i32, i32, { [0 x float] })
declare ptr addrspace(1) @_Z14clspv.resource.1(i32, i32, i32, i32, i32, i32, { [0 x float] })
declare ptr addrspace(1) @_Z14clspv.resource.2(i32, i32, i32, i32, i32, i32, { [0 x float] })

define dso_local spir_func float @helper(ptr nofree %arrs, i32 %idx, i32 %elem) {
entry:
  %slot = getelementptr [2 x ptr addrspace(1)], ptr %arrs, i32 0, i32 %idx
  %buf = load ptr addrspace(1), ptr %slot, align 4
  %gep = getelementptr float, ptr addrspace(1) %buf, i32 %elem
  %val = load float, ptr addrspace(1) %gep, align 4
  ret float %val
}

define dso_local spir_kernel void @foo(ptr addrspace(1) %out, ptr addrspace(1) %a, ptr addrspace(1) %b, i32 %idx, i32 %elem) {
entry:
  %res0 = call ptr addrspace(1) @_Z14clspv.resource.0(i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, { [0 x float] } zeroinitializer)
  %res1 = call ptr addrspace(1) @_Z14clspv.resource.1(i32 0, i32 1, i32 0, i32 1, i32 1, i32 0, { [0 x float] } zeroinitializer)
  %res2 = call ptr addrspace(1) @_Z14clspv.resource.2(i32 0, i32 2, i32 0, i32 2, i32 2, i32 0, { [0 x float] } zeroinitializer)
  %arrs = alloca [2 x ptr addrspace(1)], align 4
  %s0 = getelementptr [2 x ptr addrspace(1)], ptr %arrs, i32 0, i32 0
  store ptr addrspace(1) %res1, ptr %s0, align 4
  %s1 = getelementptr [2 x ptr addrspace(1)], ptr %arrs, i32 0, i32 1
  store ptr addrspace(1) %res2, ptr %s1, align 4
  %v = call spir_func float @helper(ptr %arrs, i32 %idx, i32 %elem)
  store float %v, ptr addrspace(1) %res0, align 4
  ret void
}
