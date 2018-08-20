{-# LANGUAGE LambdaCase #-}

module Axel.Quote where

import qualified Axel.AST as AST
  ( Expression(EFunctionApplication, EIdentifier, ELiteral)
  , FunctionApplication(FunctionApplication)
  , Literal(LChar, LInt, LString)
  )
import qualified Axel.Parse as Parse
  ( Expression(LiteralChar, LiteralInt, LiteralString, SExpression,
           Symbol)
  )

quoteList :: [Parse.Expression] -> AST.Expression
quoteList =
  foldr
    (\x acc ->
       AST.EFunctionApplication
         (AST.FunctionApplication
            (AST.EIdentifier ":")
            [quoteParseExpression x, acc]))
    (AST.EIdentifier "[]")

-- TODO Derive this with Template Haskell (it's really brittle, currently).
quoteParseExpression :: Parse.Expression -> AST.Expression
quoteParseExpression (Parse.LiteralChar x) =
  AST.EFunctionApplication $
  AST.FunctionApplication
    (AST.EIdentifier "AST.LiteralChar")
    [AST.ELiteral $ AST.LChar x]
quoteParseExpression (Parse.LiteralInt x) =
  AST.EFunctionApplication $
  AST.FunctionApplication
    (AST.EIdentifier "AST.LiteralInt")
    [AST.ELiteral $ AST.LInt x]
quoteParseExpression (Parse.LiteralString x) =
  AST.EFunctionApplication $
  AST.FunctionApplication
    (AST.EIdentifier "AST.LiteralString")
    [AST.ELiteral $ AST.LString x]
quoteParseExpression (Parse.SExpression xs) =
  AST.EFunctionApplication $
  AST.FunctionApplication (AST.EIdentifier "AST.SExpression") [quoteList xs]
quoteParseExpression (Parse.Symbol x) =
  AST.EFunctionApplication $
  AST.FunctionApplication
    (AST.EIdentifier "AST.Symbol")
    [AST.ELiteral $ AST.LString $ handleEscapes x]
  where
    handleEscapes =
      concatMap $ \case
        '\\' -> "\\\\"
        c -> [c]
