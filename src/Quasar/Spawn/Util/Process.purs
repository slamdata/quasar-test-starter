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

module Quasar.Spawn.Util.Process (CWD, spawnMongo, spawnQuasarInit, spawnQuasar) where

import Prelude

import Control.Monad.Aff (Aff, apathize, launchAff)
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Aff.AVar as AV
import Control.Monad.Aff.Console (log)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Exception (EXCEPTION, error)
import Control.Monad.Error.Class (throwError)
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..))
import Data.String as Str
import Node.Buffer (BUFFER)
import Node.ChildProcess as CP
import Quasar.Spawn.Util.Starter (starter, expectStdOut)

type CWD = String
type JarPath = String
type Options = String
type Port = Int

spawnMongo
  ∷ ∀ eff
  . CWD
  → Port
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, exception ∷ EXCEPTION | eff) CP.ChildProcess
spawnMongo cwd port = do
  starter "MongoDB" (expectStdOut "waiting for connections") $
    liftEff $
      CP.spawn
        "mongod"
        ["--port", show port, "--dbpath", "db"]
        (CP.defaultSpawnOptions { cwd = Just cwd })

spawnQuasarInit
  ∷ ∀ eff
  . CWD
  → JarPath
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, buffer ∷ BUFFER, console ∷ CONSOLE, exception ∷ EXCEPTION | eff) Unit
spawnQuasarInit config jar = do
  log "Starting Quasar initUpdateMetaStore..."
  var ← AV.makeVar
  _ ← liftEff do
    cp ← CP.spawn
      "java"
      (quasarMemOptions <> ["-jar", jar, "initUpdateMetaStore", "-c", config])
      CP.defaultSpawnOptions
    CP.onExit cp case _ of
      CP.Normally _ →
        void $ launchAff $ apathize $ AV.putVar var (Right unit)
      _ →
        void $ launchAff $ apathize $ AV.putVar var (Left unit)
  either (const (throwError (error "Process exited abnormally"))) (const (pure unit)) =<< AV.takeVar var

spawnQuasar
  ∷ ∀ eff
  . CWD
  → JarPath
  → Options
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, buffer ∷ BUFFER, console ∷ CONSOLE, exception ∷ EXCEPTION | eff) CP.ChildProcess
spawnQuasar config jar opts =
  starter "Quasar" (expectStdOut "Press Enter to stop") $
    liftEff $
      CP.spawn
        "java"
        (quasarMemOptions <> ["-jar", jar, "-c", config, "-L", "/slamdata"] <> Str.split (Str.Pattern " ") opts)
        CP.defaultSpawnOptions

quasarMemOptions ∷ Array String
quasarMemOptions = ["-Xms1g", "-Xmx2g", "-server"]
