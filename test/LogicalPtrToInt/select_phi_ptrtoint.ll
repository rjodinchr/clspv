; RUN: clspv-opt %s -o %t.ll --passes=logical-pointer-to-int
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spirv32-unknown-vulkan"

; CHECK-LABEL: define spir_kernel void @foo(
; CHECK-NOT: ptrtoint
; CHECK: %[[SEL:[a-zA-Z0-9_]+]] = select i1 %cond, i32 {{[0-9]+}}, i32 {{[0-9]+}}
; CHECK: store i32 %[[SEL]], ptr addrspace(1) %out, align 4

define spir_kernel void @foo(ptr addrspace(1) %out, i1 %cond) {
entry:
  %a = alloca [4 x i32], align 4
  %gep1 = getelementptr [4 x i32], ptr %a, i32 0, i32 1
  %gep2 = getelementptr [4 x i32], ptr %a, i32 0, i32 3
  %sel = select i1 %cond, ptr %gep1, ptr %gep2
  %pti = ptrtoint ptr %sel to i32
  store i32 %pti, ptr addrspace(1) %out, align 4
  ret void
}
