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

import Control.Monad.Aff (Aff, launchAff, delay, forkAff)
import Control.Monad.Aff.AVar (AVar, AVAR, makeVar, takeVar, putVar, tryPeekVar)
import Control.Monad.Aff.Console (CONSOLE, log)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Exception (EXCEPTION, error)
import Control.Monad.Error.Class (throwError)
import Data.Either (Either(..), either)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), isNothing)
import Data.Posix.Signal (Signal(SIGTERM))
import Data.String as Str
import Data.Time.Duration (Milliseconds(..))
import Node.ChildProcess as CP
import Node.Encoding as Enc
import Node.Stream as Stream
import Text.Chalky as Chalky

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
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, exception ∷ EXCEPTION | eff) CP.ChildProcess
  → Aff (avar ∷ AVAR, cp ∷ CP.CHILD_PROCESS, console ∷ CONSOLE, exception ∷ EXCEPTION | eff) CP.ChildProcess
starter name check spawnProc = do
  log $ Chalky.bold $ "Starting " <> name <> "..."
  var ← makeVar
  proc ← spawnProc
  liftEff do
    Stream.onDataString (CP.stderr proc) Enc.UTF8 (checker var check <<< Left)
    Stream.onDataString (CP.stdout proc) Enc.UTF8 (checker var check <<< Right)
  _ ← forkAff do
    delay (Milliseconds 30000.0)
    putVar var $ Just ("Timed out")
  v ← takeVar var
  case v of
    Nothing → log (Chalky.bold "Started") $> proc
    Just err → do
      _ ← liftEff $ CP.kill SIGTERM proc
      log (Chalky.red err)
      throwError (error "Starting process failed")

-- When we expect something from stdout we allow anything in stderr
expectStdOut ∷ String → Either String String → Maybe (Either String Unit)
expectStdOut expected (Right msg)
  | Str.contains (Str.Pattern expected) msg = Just (Right unit)
  | otherwise = Nothing
expectStdOut _ _ = Nothing

-- And when we expect something from stderr we allow anything in stdout
expectStdErr ∷ String → Either String String → Maybe (Either String Unit)
expectStdErr expected (Left msg)
  | Str.contains (Str.Pattern expected) msg = Just (Right unit)
  | otherwise = Nothing
expectStdErr _ _ = Nothing

checker
  ∷ ∀ eff
  . AVar (Maybe String)
  → (Either String String → Maybe (Either String Unit))
  → Either String String
  → Eff (console ∷ CONSOLE, avar ∷ AVAR, exception ∷ EXCEPTION | eff) Unit
checker var check msg = void $ launchAff do
  b ← isNothing <$> tryPeekVar var
  when b do
    log $ either Chalky.yellow Chalky.cyan msg
    for_ (check msg) $
      putVar var <<<
        either (Just <<< ("An error occurred: " <> _)) (const Nothing)
