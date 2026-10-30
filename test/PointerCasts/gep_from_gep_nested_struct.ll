; RUN: clspv-opt %s -o %t.ll --passes=simplify-pointer-bitcast
; RUN: FileCheck %s < %t.ll

; CHECK-LABEL: define spir_kernel void @test(
; CHECK: %[[GEP:[a-zA-Z0-9_.]+]] = getelementptr %struct.Outer, ptr addrspace(1) %buf, i32 %idx, i32 0, i32 1
; CHECK: store i32 42, ptr addrspace(1) %[[GEP]], align 4

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

%struct.Inner = type { i32, i32 }
%struct.Middle = type { %struct.Inner, i32 }
%struct.Outer = type { %struct.Middle }

define spir_kernel void @test(ptr addrspace(1) %buf, i32 %idx) {
entry:
  %base = getelementptr %struct.Outer, ptr addrspace(1) %buf, i32 %idx, i32 0
  %gep = getelementptr i32, ptr addrspace(1) %base, i32 2
  store i32 42, ptr addrspace(1) %gep, align 4
  ret void
}
