; RUN: clspv-opt %s -o %t.ll --passes=normalize-global-variables
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spirv32-unknown-vulkan"

%struct.Pair = type { i32, float }

; CHECK: @table = addrspace(2) constant [2 x %struct.Pair] [%struct.Pair { i32 1, float 2.000000e+00 }, %struct.Pair { i32 3, float 4.000000e+00 }]
; CHECK-LABEL: define spir_kernel void @foo(
; CHECK: getelementptr inbounds [2 x %struct.Pair], ptr addrspace(2) @table, i32 0, i32 %i, i32 0

@table = addrspace(2) constant <{ %struct.Pair, %struct.Pair }> <{ %struct.Pair { i32 1, float 2.000000e+00 }, %struct.Pair { i32 3, float 4.000000e+00 } }>, align 4

define spir_kernel void @foo(ptr addrspace(1) %out, i32 %i) {
entry:
  %gep = getelementptr inbounds [2 x %struct.Pair], ptr addrspace(2) @table, i32 0, i32 %i, i32 0
  %ld = load i32, ptr addrspace(2) %gep, align 4
  store i32 %ld, ptr addrspace(1) %out, align 4
  ret void
}
