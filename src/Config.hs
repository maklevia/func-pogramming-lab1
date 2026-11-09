{-# LANGUAGE OverloadedStrings #-}

module Config
  ( Config (..)
  , loadConfig
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BC
import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data Config = Config
  { configHost      :: String
  , configPort      :: Int
  , configDatabase  :: ByteString
  , configUser      :: ByteString
  , configPassword  :: ByteString
  , configWebPort   :: Int
  } deriving (Show)

loadConfig :: IO Config
loadConfig = do
  host <- fromMaybe "127.0.0.1" <$> lookupEnv "DB_HOST"
  port <- readEnvInt "DB_PORT" 3306
  database <- readEnvBS "DB_NAME" "sport_faculty"
  user <- readEnvBS "DB_USER" "sport_user"
  password <- readEnvBS "DB_PASSWORD" "sport_pass"
  webPort <- readEnvInt "PORT" 3000
  pure Config
    { configHost = host
    , configPort = port
    , configDatabase = database
    , configUser = user
    , configPassword = password
    , configWebPort = webPort
    }

readEnvBS :: String -> ByteString -> IO ByteString
readEnvBS key fallback =
  maybe fallback BC.pack <$> lookupEnv key

readEnvInt :: String -> Int -> IO Int
readEnvInt key fallback = do
  value <- lookupEnv key
  pure $ maybe fallback (fromMaybe fallback . readMaybe) value
