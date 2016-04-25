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

module Quasar.Spawn.Util.Starter where

import Prelude

import Control.Monad.Aff (Aff, launchAff, later', forkAff)
import Control.Monad.Aff.AVar (AVAR, makeVar, takeVar, putVar)
import Control.Monad.Aff.Console (log)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Exception (EXCEPTION, error)
import Control.Monad.Error.Class (throwError)

import Data.Functor (($>))
import Data.Maybe (Maybe(..), isJust)
import Data.Posix.Signal (Signal(SIGTERM))
import Data.String as Str

import Node.ChildProcess as CP
import Node.Encoding as Enc
import Node.Stream as Stream

-- | Wraps an `Aff` action that spawns a child process, adding a listener that
-- | waits for a particular string to appear in the spawned process's stdout
-- | before considering it to have successfully started.
-- |
-- | For example:
-- | ``` purescript
-- | spawny "MongoDB" "[initandlisten] waiting for connections" $ liftEff $
-- |   CP.spawn
-- |     "mongod"
-- |     (Str.split " " "--port 63174 --dbpath db")
-- |     (CP.defaultSpawnOptions { cwd = Just "test/tmp" })
-- | ```
starter
  ∷ ∀ eff
  . String
  → String
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, err ∷ EXCEPTION | eff) CP.ChildProcess
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, err ∷ EXCEPTION | eff) CP.ChildProcess
starter name startLine spawnProc = do
  log $ "Starting " ++ name ++ "..."
  var ← makeVar
  proc ← spawnProc
  liftEff $ Stream.onDataString (CP.stderr proc) Enc.UTF8 \s →
    launchAff $ putVar var $ Just $ error $ "An error occurred: " ++ s
  liftEff $ Stream.onDataString (CP.stdout proc) Enc.UTF8 \s →
    launchAff
      if isJust (Str.indexOf startLine s)
      then putVar var Nothing
      else pure unit
  forkAff $ later' 10000 $ putVar var $ Just (error "Timed out")
  v ← takeVar var
  case v of
    Nothing → log "Started" $> proc
    Just err → do
      liftEff $ CP.kill SIGTERM proc
      throwError err
