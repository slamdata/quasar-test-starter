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

module Main where

import Prelude

import Control.Monad.Aff (launchAff)
import Control.Monad.Aff.Unsafe (unsafeCoerceAff)
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Aff.Console (log)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Exception (EXCEPTION)

import Data.Maybe (Maybe(..))
import Data.Monoid (mempty)

import Node.Buffer (BUFFER)
import Node.ChildProcess as CP
import Node.FS (FS)
import Node.FS.Aff as FSA
import Node.Yargs.Applicative as Y

import Quasar.Spawn.Util.FS as FS
import Quasar.Spawn.Util.Process (spawnMongo, spawnQuasar, spawnQuasarInit)
import Quasar.Spawn.Util.TestData as TD

type Effects = (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, fs ∷ FS, buffer ∷ BUFFER, console ∷ CONSOLE, exception ∷ EXCEPTION)

main ∷ Eff Effects Unit
main = Y.runY mempty $
  app <$> Y.flag "reset" [] (Just "Reset the config and test database, run initUpdateMetaStore")

app ∷ Boolean → Eff Effects Unit
app reset = void $ launchAff $ unsafeCoerceAff do

  dbExists ← FSA.exists "tmp/db"
  quasarExists ← FSA.exists "tmp/quasar"

  let uninitialised = not dbExists || not quasarExists

  when reset $ log "Resetting config and test database"
  when uninitialised $ log "Initializing config and test database"

  let b = reset || uninitialised

  when b do
    FS.rmRec "tmp"
    FS.mkdirRec "tmp/db"
    FS.mkdirRec "tmp/quasar"
    void $ spawnMongo "tmp" 63174
    TD.importTestData 63174 "data"
    FSA.readFile "quasar/config.json" >>= FSA.writeFile "tmp/quasar/config.json"
    void $ spawnQuasarInit "tmp/quasar/config.json" "quasar/quasar.jar"

  when (not b) do
    FS.mkdirRec "tmp/db"
    FS.mkdirRec "tmp/quasar"
    void $ spawnMongo "tmp" 63174

  void $ spawnQuasar "tmp/quasar/config.json" "quasar/quasar.jar" "-C slamdata"
