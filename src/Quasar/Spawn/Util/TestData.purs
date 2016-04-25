{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module Quasar.Spawn.Util.TestData where

import Prelude

import Control.Monad.Aff (Aff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Aff.Console (log)
import Control.Monad.Eff.Class (liftEff)

import Data.Foldable (for_)
import Data.Maybe (Maybe(..))

import Node.FS (FS)
import Node.FS.Aff as FSA
import Node.ChildProcess as CP

type Port = Int

-- | Uses `mongoimport` to import data into a local MongoDB instance running
-- | on the specified port, loading data from each file in a directory.
importTestData
  ∷ ∀ eff
  . Port
  → String
  → Aff (fs ∷ FS, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE | eff) Unit
importTestData port path = do
  dataFiles ← FSA.readdir path
  for_ dataFiles \file → do
    log $ "Importing test data from file '" <> file <> "'"
    liftEff $ CP.spawn
      "mongoimport"
      ["--port", show port, "--file", file]
      (CP.defaultSpawnOptions { cwd = Just path })
