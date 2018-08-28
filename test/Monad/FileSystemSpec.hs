module Monad.FileSystemSpec where

import qualified Axel.Monad.FileSystem as FS

import Control.Lens
import Control.Monad.Except

import qualified Monad.FileSystemMock as Mock

import System.FilePath

import Test.Tasty.Hspec

spec_FileSystem :: SpecWith ()
spec_FileSystem = do
  describe "getDirectoryContentsRec" $ do
    it "gets the files inside a directory and all its subdirectories" $ do
      let action = FS.getDirectoryContentsRec "dir1"
      let origState =
            Mock.mkFSState
              [ Mock.Directory
                  "dir1"
                  [ Mock.File "file1" ""
                  , Mock.Directory
                      "dir2"
                      [Mock.File "file2" "", Mock.Directory "dir3" []]
                  ]
              ]
      let expected = ["dir1/file1", "dir1/dir2/file2"]
      case Mock.runFileSystem origState action of
        Left err -> expectationFailure err
        Right result -> result `shouldBe` (expected, origState)
  describe "withCurrentDirectory" $ do
    it "changes the directory and resets it afterwards" $ do
      let action = do
            FS.withCurrentDirectory "inside/subdir" $
              FS.writeFile "insideDir" "insideDirContents"
            FS.writeFile "outsideDir" "outsideDirContents"
      let origState =
            Mock.mkFSState
              [ Mock.Directory
                  "inside"
                  [ Mock.Directory "subdir" [Mock.File "bar" "barContents"]
                  , Mock.File "foo" "fooContents"
                  ]
              ]
      let expected =
            origState &
            (Mock.fsRoot . at "inside/subdir/insideDir" ?~
             Mock.File "insideDir" "insideDirContents") &
            (Mock.fsRoot . at "outsideDir" ?~
             Mock.File "outsideDir" "outsideDirContents")
      case Mock.runFileSystem origState action of
        Left err -> expectationFailure err
        Right result -> result `shouldBe` ((), expected)
  describe "withTemporaryDirectory" $ do
    it
      "creates a temporary directory and resets the current directory afterwards" $ do
      let action = do
            FS.withTemporaryDirectory $ \tempDir ->
              FS.writeFile (tempDir </> "insideTemp1") "insideTemp1Contents"
            FS.withTemporaryDirectory $ \tempDir ->
              FS.writeFile (tempDir </> "insideTemp2") "insideTemp2Contents"
      let origState = Mock.mkFSState []
      let expected =
            origState &
            (Mock.fsRoot . at "tmp1" ?~
             Mock.Directory
               "tmp1"
               [Mock.File "insideTemp1" "insideTemp1Contents"]) &
            (Mock.fsRoot . at "tmp2" ?~
             Mock.Directory
               "tmp2"
               [Mock.File "insideTemp2" "insideTemp2Contents"]) &
            (Mock.fsTempCounter .~ 2)
      case Mock.runFileSystem origState action of
        Left err -> expectationFailure err
        Right result -> result `shouldBe` ((), expected)