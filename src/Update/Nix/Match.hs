{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Update.Nix.Match where

import           Control.Category               ( (>>>) )
import           Control.DeepSeq
import           Control.Exception              ( evaluate )
import           Data.Coerce
import           Data.Fix                       ( Fix(..) )
import           Data.Foldable
import           Data.Text                      ( Text )
import qualified Data.Text                     as T
import qualified Data.Text.IO                  as T
import           Nix
import           Nix.TH                         ( nix )
import           Say
import           Unsafe.Coerce                  ( unsafeCoerce )

import           Nix.Match

test :: IO ()
test = do
  let needle = annotateNullSourcePos [nix|
        callPackage (
          _:
          mkDerivation {
            broken = true;
            pname = ^name;
            version = ^version;
          }
        ) {}
      |]
  sayErr "Parsing"
  Success haystack <-
    parseNixFileLoc
      "/home/j/src/nixpkgs/pkgs/development/haskell-modules/hackage-packages.nix"
  sayErr "Parsed"
  Control.Exception.evaluate . Control.DeepSeq.force $ haystack
  sayErr "Evaluated"
  let matches = findMatches (addHolesLoc needle) haystack
      tags =
        [ t <> ": " <> str
        | (_, ms) <- matches
        , (t, e ) <- ms
        , let str = T.pack . show . prettyNix . stripAnnotation $ e
        ]
  traverse_ T.putStrLn tags

annotateNullSourcePos :: NExpr -> NExprLoc
annotateNullSourcePos =
  Fix
    . Compose
    . fmap (fmap annotateNullSourcePos)
    . Ann (SrcSpan nullSourcePos nullSourcePos)
    . unFix

nullSourcePos :: SourcePos
nullSourcePos = SourcePos "" (mkPos 1) (mkPos 1)
