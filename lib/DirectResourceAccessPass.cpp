// Copyright 2018 The Clspv Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <climits>
#include <map>
#include <set>
#include <utility>
#include <vector>

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/UniqueVector.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"

#include "clspv/Option.h"

#include "ArgKind.h"
#include "Builtins.h"
#include "CallGraphOrderedFunctions.h"
#include "Constants.h"
#include "DirectResourceAccessPass.h"
#include "Types.h"

using namespace llvm;

#define DEBUG_TYPE "directresourceaccess"

namespace {

cl::opt<bool> ShowDRA("show-dra", cl::init(false), cl::Hidden,
                      cl::desc("Show direct resource access details"));

struct ParamInfo {
  Value *base = nullptr;
  uint32_t set = 0;
  uint32_t binding = 0;
  Type *pointee_type = nullptr;
  unsigned num_gep_zeroes = 0;
  CallInst *sample_call = nullptr;

  bool operator==(const ParamInfo &other) const {
    return base == other.base && set == other.set && binding == other.binding &&
           num_gep_zeroes == other.num_gep_zeroes;
  }
  bool operator!=(const ParamInfo &other) const { return !(*this == other); }
};

bool ExtractParamInfo(Value *value, ParamInfo &pi, bool allow_null = false) {
  if (allow_null &&
      (isa<ConstantPointerNull>(value) || isa<UndefValue>(value))) {
    pi = {value, 0, 0, nullptr, 0, nullptr};
    return true;
  }
  unsigned num_gep_zeroes = 0;
  bool first_gep = true;
  for (auto *gep = dyn_cast<GetElementPtrInst>(value); gep;
       gep = dyn_cast<GetElementPtrInst>(value)) {
    if (!gep->hasAllZeroIndices()) {
      return false;
    }
    num_gep_zeroes += gep->getNumIndices() + (first_gep ? 0 : -1);
    value = gep->getPointerOperand();
    first_gep = false;
  }
  if (auto *call = dyn_cast<CallInst>(value)) {
    auto *callee = call->getCalledFunction();
    auto &func_info = clspv::Builtins::Lookup(callee);
    if (func_info.getType() == clspv::Builtins::kClspvResource) {
      const auto set = uint32_t(
          dyn_cast<ConstantInt>(
              call->getOperand(clspv::ClspvOperand::kResourceDescriptorSet))
              ->getZExtValue());
      const auto binding =
          uint32_t(dyn_cast<ConstantInt>(
                       call->getOperand(clspv::ClspvOperand::kResourceBinding))
                       ->getZExtValue());
      auto *resource_type =
          call->getOperand(clspv::ClspvOperand::kResourceDataType)->getType();
      pi = {callee, set, binding, resource_type, num_gep_zeroes, call};
      return true;
    } else if (!allow_null &&
               func_info.getType() == clspv::Builtins::kClspvLocal) {
      const uint32_t spec_id =
          uint32_t(dyn_cast<ConstantInt>(
                       call->getOperand(clspv::ClspvOperand::kWorkgroupSpecId))
                       ->getZExtValue());
      auto *array_ty =
          call->getOperand(clspv::ClspvOperand::kWorkgroupDataType)->getType();
      pi = {callee, spec_id, 0, array_ty, num_gep_zeroes, call};
      return true;
    }
  } else if (!allow_null) {
    if (auto *gv = dyn_cast<GlobalValue>(value)) {
      pi = {value, 0, 0, gv->getValueType(), num_gep_zeroes, nullptr};
      return true;
    }
  }
  return false;
}

Value *MaterializeParamInfo(IRBuilder<> &Builder, const ParamInfo &pi) {
  Value *replacement = pi.base;
  if (auto *function = dyn_cast<Function>(replacement)) {
    SmallVector<Value *, 8> args(pi.sample_call->arg_begin(),
                                 pi.sample_call->arg_end());
    replacement = Builder.CreateCall(function, args);
    if (ShowDRA) {
      outs() << "DRA:    Replace: call " << *replacement << "\n";
    }
  }
  if (pi.num_gep_zeroes) {
    SmallVector<Value *, 3> zeroes(pi.num_gep_zeroes, Builder.getInt32(0));
    replacement =
        GetElementPtrInst::Create(pi.pointee_type, replacement, zeroes);
    Builder.Insert(cast<Instruction>(replacement));
    if (ShowDRA) {
      outs() << "DRA:    Replace: gep  " << *replacement << "\n";
    }
  }
  return replacement;
}

bool ReplaceLoadsFromPointerArray(Value *container, ArrayRef<Value *> elems) {
  bool changed = false;
  SmallVector<std::pair<Value *, Value *>, 8> worklist;
  worklist.push_back({container, nullptr});
  SmallVector<LoadInst *, 8> loads_to_erase;
  SmallVector<GetElementPtrInst *, 8> geps;

  while (!worklist.empty()) {
    auto [curr, curr_idx] = worklist.pop_back_val();
    for (Use &u : curr->uses()) {
      User *usr = u.getUser();
      if (auto *ld = dyn_cast<LoadInst>(usr)) {
        if (!curr_idx) {
          ld->replaceAllUsesWith(elems[0]);
        } else if (auto *cst = dyn_cast<ConstantInt>(curr_idx)) {
          uint64_t k =
              std::min<uint64_t>(cst->getZExtValue(), elems.size() - 1);
          ld->replaceAllUsesWith(elems[k]);
        } else {
          IRBuilder<> B(ld);
          Value *sel = elems[0];
          for (size_t k = 1; k < elems.size(); ++k) {
            Value *cmp = B.CreateICmpEQ(
                curr_idx, ConstantInt::get(curr_idx->getType(), k));
            sel = B.CreateSelect(cmp, elems[k], sel);
          }
          ld->replaceAllUsesWith(sel);
        }
        loads_to_erase.push_back(ld);
        changed = true;
      } else if (auto *gep = dyn_cast<GetElementPtrInst>(usr)) {
        geps.push_back(gep);
        Value *next_idx = curr_idx;
        if (!gep->hasAllZeroIndices()) {
          next_idx = gep->getOperand(gep->getNumOperands() - 1);
        }
        worklist.push_back({gep, next_idx});
      }
    }
  }

  for (LoadInst *ld : loads_to_erase) {
    ld->eraseFromParent();
  }
  for (auto it = geps.rbegin(); it != geps.rend(); ++it) {
    if ((*it)->use_empty()) {
      (*it)->eraseFromParent();
    }
  }
  return changed;
}

void EraseDeadPointerArrayAlloca(AllocaInst *alloca) {
  SmallVector<Value *, 8> worklist{alloca};
  SmallVector<Instruction *, 16> leaf_insts;
  SmallVector<Instruction *, 16> addr_insts;
  while (!worklist.empty()) {
    Value *v = worklist.pop_back_val();
    for (Use &u : v->uses()) {
      User *usr = u.getUser();
      if (auto *st = dyn_cast<StoreInst>(usr)) {
        if (st->getValueOperand() == v) {
          return;
        }
        leaf_insts.push_back(st);
      } else if (auto *ii = dyn_cast<IntrinsicInst>(usr)) {
        if (ii->isLifetimeStartOrEnd()) {
          leaf_insts.push_back(ii);
        } else {
          return;
        }
      } else if (isa<GetElementPtrInst>(usr) || isa<BitCastInst>(usr)) {
        auto *inst = cast<Instruction>(usr);
        addr_insts.push_back(inst);
        worklist.push_back(inst);
      } else {
        return;
      }
    }
  }
  for (Instruction *inst : leaf_insts) {
    inst->eraseFromParent();
  }
  for (auto it = addr_insts.rbegin(); it != addr_insts.rend(); ++it) {
    if ((*it)->use_empty()) {
      (*it)->eraseFromParent();
    }
  }
  if (alloca->use_empty()) {
    alloca->eraseFromParent();
  }
}

void RewritePointerArrayAccesses(
    Module &M, const UniqueVector<Function *> &ordered_functions) {
  const DataLayout &DL = M.getDataLayout();
  DenseMap<Value *, SmallVector<ParamInfo, 8>> ptr_array_map;
  SmallVector<AllocaInst *, 8> all_ptr_allocas;

  for (Function &F : M) {
    for (BasicBlock &BB : F) {
      for (Instruction &I : BB) {
        auto *alloca = dyn_cast<AllocaInst>(&I);
        if (!alloca)
          continue;
        auto *arr_ty = dyn_cast<ArrayType>(alloca->getAllocatedType());
        if (!arr_ty || !arr_ty->getElementType()->isPointerTy())
          continue;

        uint64_t N = arr_ty->getNumElements();
        if (N == 0)
          continue;
        auto *elem_ptr_ty = cast<PointerType>(arr_ty->getElementType());
        uint64_t ptr_size = DL.getTypeAllocSize(elem_ptr_ty);
        SmallVector<Value *, 8> elems(N, ConstantPointerNull::get(elem_ptr_ty));

        for (BasicBlock &ScanBB : F) {
          for (Instruction &ScanI : ScanBB) {
            auto *st = dyn_cast<StoreInst>(&ScanI);
            if (!st)
              continue;
            Value *ptr_op = st->getPointerOperand();
            uint64_t idx = UINT64_MAX;
            if (ptr_op == alloca) {
              idx = 0;
            } else if (auto *gep = dyn_cast<GetElementPtrInst>(ptr_op)) {
              if (gep->getPointerOperand() == alloca) {
                APInt offset(
                    DL.getIndexSizeInBits(gep->getPointerAddressSpace()), 0);
                if (gep->accumulateConstantOffset(DL, offset)) {
                  idx = offset.getZExtValue() / ptr_size;
                }
              }
            }
            if (idx < N) {
              Value *val = st->getValueOperand();
              if (!isa<ConstantPointerNull>(val) && !isa<UndefValue>(val)) {
                elems[idx] = val;
              }
            }
          }
        }

        ReplaceLoadsFromPointerArray(alloca, elems);
        all_ptr_allocas.push_back(alloca);

        SmallVector<ParamInfo, 8> info_vec(N);
        bool all_valid = true;
        for (uint64_t k = 0; k < N; ++k) {
          if (!ExtractParamInfo(elems[k], info_vec[k], /*allow_null=*/true)) {
            all_valid = false;
            break;
          }
        }
        if (all_valid) {
          ptr_array_map[alloca] = std::move(info_vec);
        }
      }
    }
  }

  SmallVector<Argument *, 16> rewritten_args;
  for (Function *fn : ordered_functions) {
    if (fn->isDeclaration() ||
        fn->getCallingConv() == CallingConv::SPIR_KERNEL || fn->use_empty())
      continue;

    int arg_index = 0;
    for (Argument &arg : fn->args()) {
      if (!arg.getType()->isPointerTy() ||
          arg.getType()->getPointerAddressSpace() !=
              clspv::AddressSpace::Private) {
        arg_index++;
        continue;
      }

      SmallVector<ParamInfo, 8> common;
      bool seen_one = false;
      bool valid = true;
      for (Use &use : fn->uses()) {
        auto *caller = dyn_cast<CallInst>(use.getUser());
        if (!caller) {
          valid = false;
          break;
        }
        Value *val = caller->getArgOperand(arg_index);
        while (auto *gep = dyn_cast<GetElementPtrInst>(val)) {
          if (!gep->hasAllZeroIndices())
            break;
          val = gep->getPointerOperand();
        }
        auto it = ptr_array_map.find(val);
        if (it == ptr_array_map.end()) {
          valid = false;
          break;
        }
        if (!seen_one) {
          common = it->second;
          seen_one = true;
        } else if (common != it->second) {
          valid = false;
          break;
        }
      }

      if (valid && seen_one) {
        ptr_array_map[&arg] = common;
        rewritten_args.push_back(&arg);

        bool has_loads = false;
        for (User *u : arg.users()) {
          if (isa<LoadInst>(u) || isa<GetElementPtrInst>(u)) {
            has_loads = true;
            break;
          }
        }
        if (has_loads) {
          IRBuilder<> Builder(fn->getParent()->getContext());
          Builder.SetInsertPoint(fn->getEntryBlock().getFirstNonPHIIt());
          SmallVector<Value *, 8> fn_elems;
          for (const auto &pi : common) {
            fn_elems.push_back(MaterializeParamInfo(Builder, pi));
          }
          ReplaceLoadsFromPointerArray(&arg, fn_elems);
        }
      }
      arg_index++;
    }
  }

  for (Argument *arg : rewritten_args) {
    Function *fn = arg->getParent();
    unsigned idx = arg->getArgNo();
    for (Use &use : fn->uses()) {
      if (auto *caller = dyn_cast<CallInst>(use.getUser())) {
        caller->setArgOperand(
            idx, ConstantPointerNull::get(cast<PointerType>(arg->getType())));
      }
    }
    SmallVector<Instruction *, 8> dead_geps;
    for (User *u : arg->users()) {
      if (auto *gep = dyn_cast<GetElementPtrInst>(u)) {
        if (gep->use_empty())
          dead_geps.push_back(gep);
      }
    }
    for (Instruction *gep : dead_geps) {
      gep->eraseFromParent();
    }
  }

  for (AllocaInst *alloca : all_ptr_allocas) {
    EraseDeadPointerArrayAlloca(alloca);
  }
}

} // namespace

PreservedAnalyses
clspv::DirectResourceAccessPass::run(Module &M, ModuleAnalysisManager &) {
  PreservedAnalyses PA;

  if (clspv::Option::DirectResourceAccess()) {
    auto ordered_functions = clspv::CallGraphOrderedFunctions(M);
    if (ShowDRA) {
      outs() << "DRA: Ordered functions:\n";
      for (Function *fun : ordered_functions) {
        outs() << "DRA:   " << fun->getName() << "\n";
      }
    }

    for (auto *fn : ordered_functions) {
      RewriteResourceAccesses(fn);
    }
    RewritePointerArrayAccesses(M, ordered_functions);
  }

  return PA;
}

bool clspv::DirectResourceAccessPass::RewriteResourceAccesses(Function *fn) {
  bool Changed = false;
  int arg_index = 0;
  for (Argument &arg : fn->args()) {
    if (clspv::IsResourceType(arg.getType())) {
      if (auto PtrTy = dyn_cast<PointerType>(arg.getType())) {
        // Look for arguments that map to resources. They appear in the
        // following address spaces.
        switch (PtrTy->getPointerAddressSpace()) {
        case clspv::AddressSpace::Global:
        case clspv::AddressSpace::Constant:
        case clspv::AddressSpace::Local:
        case clspv::AddressSpace::UniformConstant:
          Changed |= RewriteAccessesForArg(fn, arg_index, arg);
          break;
        default:
          break;
        }
      } else {
        // Images and samplers.
        Changed |= RewriteAccessesForArg(fn, arg_index, arg);
      }
    }
    arg_index++;
  }
  return Changed;
}

// Rewrites, if possible, all the arg_index'th arg to all callers to 'fn',
// to replace passing the resource by pointer argument to directly accessing
// the underlying global variable for the resource.  This is only possible
// when all callers call 'fn' with the same underlying resource variable.
// Returns true if a change was made.
bool clspv::DirectResourceAccessPass::RewriteAccessesForArg(Function *fn,
                                                            int arg_index,
                                                            Argument &arg) {
  if (fn->use_empty()) {
    return false;
  }

  ParamInfo common = {};
  bool seen_one = false;
  for (auto &use : fn->uses()) {
    auto *caller = dyn_cast<CallInst>(use.getUser());
    if (!caller)
      return false;
    ParamInfo pi;
    if (!ExtractParamInfo(caller->getArgOperand(arg_index), pi))
      return false;
    if (!seen_one) {
      common = pi;
      seen_one = true;
    } else if (pi != common) {
      return false;
    }
  }
  if (ShowDRA) {
    if (seen_one) {
      outs() << "DRA:  Rewrite " << fn->getName() << " arg " << arg_index << " "
             << arg.getName() << ": " << common.base->getName() << " ("
             << common.set << "," << common.binding
             << ") zeroes: " << common.num_gep_zeroes << " sample-call ";
      if (common.sample_call)
        outs() << *common.sample_call << "\n";
      else
        outs() << "nullptr\n";
    }
  }

  // Now rewrite the argument, using the info in |common|.
  IRBuilder<> Builder(fn->getParent()->getContext());
  Builder.SetInsertPoint(fn->getEntryBlock().getFirstNonPHIIt());
  Value *replacement = MaterializeParamInfo(Builder, common);
  arg.replaceAllUsesWith(replacement);

  return true;
}
