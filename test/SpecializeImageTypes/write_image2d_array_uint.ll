; RUN: clspv-opt --passes=specialize-image-types %s -o %t
; RUN: FileCheck %s < %t

; CHECK: declare spir_func void @_Z13write_imageui{{.*}}([[image:target\(\"spirv.Image\", i32, 1, 0, 1, 0, 2, 0, 1, 1\)]], <4 x i32>, <4 x i32>) [[ATTRS:#[0-9]+]]
; CHECK: define spir_kernel void @write_uint
; CHECK: call spir_func void @_Z13write_imageui{{.*}}([[image]] %image
; CHECK: attributes [[ATTRS]] = { convergent nounwind }

target datalayout = "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir-unknown-unknown"

%opencl.image2d_array_wo_t = type opaque

define spir_kernel void @write_uint(target("spirv.Image", void, 1, 0, 1, 0, 0, 0, 1) %image, <4 x i32> %coord, ptr addrspace(1) nocapture %data) local_unnamed_addr #0 {
entry:
  %ld = load <4 x i32>, ptr addrspace(1) %data, align 16
  call spir_func void @_Z13write_imageui20ocl_image2d_array_woDv4_iDv4_j(target("spirv.Image", void, 1, 0, 1, 0, 0, 0, 1) %image, <4 x i32> %coord, <4 x i32> %ld) #2
  ret void
}

declare spir_func void @_Z13write_imageui20ocl_image2d_array_woDv4_iDv4_j(target("spirv.Image", void, 1, 0, 1, 0, 0, 0, 1), <4 x i32>, <4 x i32>) local_unnamed_addr #1

attributes #0 = { convergent }
attributes #1 = { convergent nounwind }
attributes #2 = { convergent nobuiltin nounwind readonly }

