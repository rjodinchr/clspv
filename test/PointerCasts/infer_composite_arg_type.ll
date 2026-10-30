; RUN: clspv-opt %s -o %t.ll --passes=simplify-pointer-bitcast
; RUN: FileCheck %s < %t.ll

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-n8:16:32:64-G1"
target triple = "spirv32-unknown-vulkan"

%struct.Pair = type { float, float }

; CHECK-LABEL: define dso_local spir_func float @read_pair(
; CHECK: %[[GEP0:[a-zA-Z0-9_.]+]] = getelementptr %struct.Pair, ptr addrspace(1) %p, i32 0, i32 0
; CHECK: %v0 = load float, ptr addrspace(1) %[[GEP0]], align 4
; CHECK: %gep1 = getelementptr %struct.Pair, ptr addrspace(1) %p, i32 0, i32 1
; CHECK: %v1 = load float, ptr addrspace(1) %gep1, align 4

define dso_local spir_func float @read_pair(ptr addrspace(1) %p) {
entry:
  %gep0 = getelementptr float, ptr addrspace(1) %p, i32 0
  %v0 = load float, ptr addrspace(1) %gep0, align 4
  %gep1 = getelementptr %struct.Pair, ptr addrspace(1) %p, i32 0, i32 1
  %v1 = load float, ptr addrspace(1) %gep1, align 4
  %sum = fadd float %v0, %v1
  ret float %sum
}
