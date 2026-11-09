{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (bracket)
import Data.Pool (defaultPoolConfig, destroyAllResources, newPool)
import Database.MySQL.Base (ConnectInfo (..), close, connect, defaultConnectInfoMB4)

import Config (Config (..), loadConfig)
import Web.App (runApp)

main :: IO ()
main = do
  config <- loadConfig
  let connectInfo =
        defaultConnectInfoMB4
          { ciHost = configHost config
          , ciPort = fromIntegral (configPort config)
          , ciDatabase = configDatabase config
          , ciUser = configUser config
          , ciPassword = configPassword config
          }
  bracket
    (newPool (defaultPoolConfig (connect connectInfo) close 30 5))
    destroyAllResources
    (runApp config)
