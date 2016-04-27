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

module Quasar.Spawn.Util.Starter
  ( starter
  , expectStdOut
  , expectStdErr
  ) where

import Prelude

import Control.Monad.Aff (Aff, launchAff, later', forkAff)
import Control.Monad.Aff.AVar (AVar, AVAR, makeVar, takeVar, putVar)
import Control.Monad.Aff.Console (log)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Exception (EXCEPTION, Error, error)
import Control.Monad.Error.Class (throwError)

import Data.Either (Either(..))
import Data.Functor (($>))
import Data.Maybe (Maybe(..))
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
  → (Either String String → Maybe (Either String Unit))
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, err ∷ EXCEPTION | eff) CP.ChildProcess
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, err ∷ EXCEPTION | eff) CP.ChildProcess
starter name check spawnProc = do
  log $ "Starting " ++ name ++ "..."
  var ← makeVar
  proc ← spawnProc
  liftEff do
    Stream.onDataString (CP.stderr proc) Enc.UTF8 (checker var check <<< Left)
    Stream.onDataString (CP.stdout proc) Enc.UTF8 (checker var check <<< Right)
  forkAff $ later' 15000 $ putVar var $ Just (error "Timed out")
  v ← takeVar var
  case v of
    Nothing → log "Started" $> proc
    Just err → do
      liftEff $ CP.kill SIGTERM proc
      throwError err

expectStdOut ∷ String → Either String String → Maybe (Either String Unit)
expectStdOut _ (Left err) = Just (Left err)
expectStdOut expected (Right msg)
  | Str.contains expected msg = Just (Right unit)
  | otherwise = Nothing

expectStdErr ∷ String → Either String String → Maybe (Either String Unit)
expectStdErr expected (Left msg)
  | Str.contains expected msg = Just (Right unit)
  | otherwise = Nothing
expectStdErr _ _ = Nothing

checker
  ∷ ∀ eff
  . AVar (Maybe Error)
  → (Either String String → Maybe (Either String Unit))
  → Either String String
  → Eff (avar ∷ AVAR, err ∷ EXCEPTION | eff) Unit
checker var check msg =
  case check msg of
    Just (Left err) →
      launchAff $ putVar var $ Just $ error $ "An error occurred: " <> err
    Just (Right _) →
      launchAff $ putVar var Nothing
    Nothing →
      pure unit
