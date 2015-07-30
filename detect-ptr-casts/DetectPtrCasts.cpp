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

class DetectPtrCastsVisitor
  : public RecursiveASTVisitor<DetectPtrCastsVisitor> {

public:
  
  explicit DetectPtrCastsVisitor(ASTContext *context, CastType castType)
    : context(context), castType(castType) {}

  bool TraverseCStyleCastExpr(CStyleCastExpr *expr) {
    if ((castType == IntToPtr) && (expr->getCastKind() == CK_IntegralToPointer)) {
      // if the value that is cast is an integral we can safely ignore it
      SourceLocation loc = expr->getExprLoc();
      if (expr->getSubExpr()->isIntegerConstantExpr(*context, &loc)) {
        printMessage(expr, "constant integer to pointer");
      } else {
        printMessage(expr, "integer to pointer");
      }
    } else if ((castType == PtrToInt) && (expr->getCastKind() == CK_PointerToIntegral)) {
      printMessage(expr, "pointer to integer");
    }
    
    return true;
  }
  
  void printMessage(CStyleCastExpr* expr, const char* what) {
    FullSourceLoc fullLocation = context->getFullLoc(expr->getLocStart());
    if (fullLocation.isValid()) {
      llvm::outs() << "\033[1;34m Found " << what << " \033[0m"
                   <<  "\033[1;37mcast at " 
                   << fullLocation.getSpellingLineNumber() << ":"
                   << fullLocation.getSpellingColumnNumber() 
                   << "\033[0m \033[1;31m"
                   << "in file: " << context->getSourceManager().getFilename(fullLocation) 
                   << "\033[0m\n";
     if (context->getSourceManager().getFilename(fullLocation) == "")
       expr->dumpColor();
    }
  }

private:
  ASTContext *context;
  CastType castType;
};

class DetectPtrCastsConsumer : public ASTConsumer {
private:
  DetectPtrCastsVisitor visitor;
public:
  explicit DetectPtrCastsConsumer(ASTContext *context, CastType castType)
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

class DetectPtrCastsAction : public PluginASTAction {
  
   CastType castType;

protected:

  std::unique_ptr<ASTConsumer> CreateASTConsumer(CompilerInstance &CI,
                                                 llvm::StringRef) override {
    return llvm::make_unique<DetectPtrCastsConsumer>(&CI.getASTContext(), castType);
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
    ros << "Help for DetectPtrCasts plugin goes here\n";
  }

};

}

static FrontendPluginRegistry::Add<DetectPtrCastsAction>
X("detect-ptr-casts", "detect pointer casts");
