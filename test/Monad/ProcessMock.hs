{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Monad.ProcessMock where

import Axel.Monad.Console as Console
import Axel.Monad.FileSystem as FS
import Axel.Monad.Haskell.GHC as GHC
import Axel.Monad.Process as Proc
import Axel.Monad.Resource as Res

import Control.Lens
import Control.Monad.Except
import Control.Monad.State.Lazy

import MockUtils

import System.Exit

type ProcessResult = (ExitCode, Maybe (String, String))

data ProcessState = ProcessState
  { _procMockArgs :: [String]
  , _procExecutionLog :: [(String, [String], Maybe String)]
  , _procMockResults :: [ProcessResult]
  } deriving (Eq, Show)

makeFieldsNoPrefix ''ProcessState

mkProcessState :: [String] -> [ProcessResult] -> ProcessState
mkProcessState mockArgs mockResults =
  ProcessState
    { _procMockArgs = mockArgs
    , _procExecutionLog = []
    , _procMockResults = mockResults
    }

newtype ProcessT m a =
  ProcessT (StateT ProcessState m a)
  deriving ( Functor
           , Applicative
           , Monad
           , MonadFileSystem
           , MonadConsole
           , MonadGHC
           , MonadResource
           )

type Process = ProcessT Identity

instance (MonadError String m) => MonadProcess (ProcessT m) where
  getArgs = ProcessT $ gets (^. procMockArgs)
  runProcess cmd args stdin =
    ProcessT $ do
      procExecutionLog %= (|> (cmd, args, Just stdin))
      gets (uncons . (^. procMockResults)) >>= \case
        Just (mockResult, newMockResults) -> do
          procMockResults .= newMockResults
          case mockResult of
            (exitCode, Just (stdout, stderr)) -> pure (exitCode, stdout, stderr)
            _ ->
              throwInterpretError
                "RunProcess"
                ("Wrong type for mock result: " <> show mockResult)
        Nothing -> throwInterpretError "RunProcess" "No mock result available"
  runProcessInheritingStreams cmd args =
    ProcessT $ do
      procExecutionLog %= (|> (cmd, args, Nothing))
      gets (uncons . (^. procMockResults)) >>= \case
        Just (mockResult, newMockResults) -> do
          procMockResults .= newMockResults
          case mockResult of
            (exitCode, Nothing) -> pure exitCode
            _ ->
              throwInterpretError
                "RunProcessInheritingStreams"
                ("Wrong type for mock result: " <> show mockResult)
        Nothing ->
          throwInterpretError
            "RunProcessInheritingStreams"
            "No mock result available"

runProcessT :: ProcessState -> ProcessT m a -> m (a, ProcessState)
runProcessT origState (ProcessT x) = runStateT x origState

runProcess :: ProcessState -> Process a -> (a, ProcessState)
runProcess origState x = runIdentity $ runProcessT origState x
