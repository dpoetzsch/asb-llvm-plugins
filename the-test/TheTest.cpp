//===- PrintFunctionNames.cpp ---------------------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Example clang plugin which simply prints the names of all the top-level decls
// in the input file.
//
//===----------------------------------------------------------------------===//

#include "clang/Frontend/FrontendPluginRegistry.h"
#include "clang/AST/AST.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Sema/Sema.h"
#include "llvm/Support/raw_ostream.h"
using namespace clang;

namespace {

enum CastType { IntToPtr, PtrToInt};

class TheTestVisitor
  : public RecursiveASTVisitor<TheTestVisitor> {

public:
  
  explicit TheTestVisitor(ASTContext *context, CastType castType)
    : context(context), castType(castType) {}

  bool TraverseCStyleCastExpr(CStyleCastExpr *expr) {
   
    if (expr->getCastKind() == CK_IntegralToPointer && castType == IntToPtr) {
      FullSourceLoc fullLocation = context->getFullLoc(expr->getLocStart());
      if (fullLocation.isValid())
        llvm::outs() << "Found integer to pointer cast at "
                     << fullLocation.getSpellingLineNumber() << ":"
                     << fullLocation.getSpellingColumnNumber() << "\n";
    }
    
    if (expr->getCastKind() == CK_PointerToIntegral && castType == PtrToInt) {
      FullSourceLoc fullLocation = context->getFullLoc(expr->getLocStart());
      if (fullLocation.isValid())
        llvm::outs() << "Found pointer to integer cast at "
                     << fullLocation.getSpellingLineNumber() << ":"
                     << fullLocation.getSpellingColumnNumber() << "\n";
    }
    
    
    return true;
  }

private:
  ASTContext *context;
  CastType castType;
};

class TheTestConsumer : public ASTConsumer {
private:
  TheTestVisitor visitor;
public:
  explicit TheTestConsumer(ASTContext *context, CastType castType)
      : visitor(context,castType)  {}

  /*bool HandleTopLevelDecl(DeclGroupRef DG) override {
    for (DeclGroupRef::iterator i = DG.begin(), e = DG.end(); i != e; ++i) {
      const Decl *D = *i;
      if (const NamedDecl *ND = dyn_cast<NamedDecl>(D))
        llvm::errs() << "top-level-decl: \"" << ND->getNameAsString() << "\"\n";
    }

    return true;
  }*/
  
  virtual void HandleTranslationUnit(clang::ASTContext &Context) {
    visitor.TraverseDecl(Context.getTranslationUnitDecl());
  }
};

class TheTestAction : public PluginASTAction {
  
   CastType castType;

protected:

  std::unique_ptr<ASTConsumer> CreateASTConsumer(CompilerInstance &CI,
                                                 llvm::StringRef) override {
    return llvm::make_unique<TheTestConsumer>(&CI.getASTContext(), castType);
  }

  bool ParseArgs(const CompilerInstance &CI,
                 const std::vector<std::string> &args) override {
    if (!args.empty() && args[0] == "help")
      PrintHelp(llvm::errs());

    if (!args.empty() && args[0] == "p2i")
      castType=PtrToInt;
    else castType=IntToPtr;

    return true;
  }
  
  void PrintHelp(llvm::raw_ostream& ros) {
    ros << "Help for TheTest plugin goes here\n";
  }

};

}

static FrontendPluginRegistry::Add<TheTestAction>
X("the-test", "the awesome test");
