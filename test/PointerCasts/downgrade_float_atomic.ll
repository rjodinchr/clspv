; RUN: clspv-opt %s -o %t.ll --passes=replace-pointer-bitcast
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spirv32-unknown-vulkan"

; CHECK-LABEL: define spir_kernel void @foo(
; CHECK: %[[GEP:[a-zA-Z0-9_]+]] = getelementptr i32, ptr addrspace(1) %buf, i32 %idx
; CHECK: atomicrmw add ptr addrspace(1) %[[GEP]], i32 1 monotonic

define spir_kernel void @foo(ptr addrspace(1) %buf, i32 %idx) {
entry:
  %gep = getelementptr float, ptr addrspace(1) %buf, i32 %idx
  %old = atomicrmw add ptr addrspace(1) %gep, i32 1 monotonic
  ret void
}
