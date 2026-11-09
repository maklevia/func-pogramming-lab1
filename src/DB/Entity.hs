{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module DB.Entity
  ( Entity (..)
  , decodeField
  , decodeEnumField
  , decodeFlexibleInt64
  , columnsMismatch
  ) where

import Data.Int (Int64)
import Data.Proxy (Proxy)
import Data.Text (Text)
import qualified Data.Text as T
import Database.MySQL.Field (Field (..))
import Database.MySQL.Protocol.MySQLValue (MySQLValue (..))
import Domain.Validation (AppError (..))
import Text.Read (readMaybe)

-- | Pure mapping between a domain type and its MySQL table row.
--
-- Contract:
--   * 'columns' lists all columns except the surrogate @id@.
--   * 'toRow' returns values in exactly the same order as 'columns'.
--   * 'fromRow' receives @id : columns@ in the same order.
class Entity a where
  tableName :: Proxy a -> Text
  columns   :: Proxy a -> [Text]
  entityId  :: a -> Int64
  toRow     :: a -> [MySQLValue]
  fromRow   :: [MySQLValue] -> Either AppError a

decodeField :: forall a. Field a => Text -> MySQLValue -> Either AppError a
decodeField label value =
  case fromField value of
    Left err -> Left (UnexpectedError ("Помилка читання поля " <> label <> ": " <> T.pack (show err)))
    Right parsed -> Right parsed

decodeEnumField :: Text -> (Text -> Maybe a) -> MySQLValue -> Either AppError a
decodeEnumField label parser value = do
  raw <- decodeField label value
  case parser raw of
    Just parsed -> Right parsed
    Nothing -> Left (UnexpectedError ("Невідоме значення поля " <> label <> ": " <> raw))

decodeFlexibleInt64 :: Text -> MySQLValue -> Either AppError Int64
decodeFlexibleInt64 label value =
  case value of
    MySQLInt64 n  -> Right n
    MySQLInt64U n -> Right (fromIntegral n)
    MySQLInt32 n  -> Right (fromIntegral n)
    MySQLInt32U n -> Right (fromIntegral n)
    MySQLInt16 n  -> Right (fromIntegral n)
    MySQLInt16U n -> Right (fromIntegral n)
    MySQLInt8 n   -> Right (fromIntegral n)
    MySQLInt8U n  -> Right (fromIntegral n)
    MySQLText t   ->
      case readMaybe (T.unpack t) of
        Just n  -> Right n
        Nothing -> Left (UnexpectedError ("Не вдалося прочитати число з поля " <> label))
    _ -> Left (UnexpectedError ("Неочікуваний тип значення в полі " <> label))

columnsMismatch :: Text -> Either AppError a
columnsMismatch entity =
  Left (UnexpectedError ("Неправильна кількість колонок для " <> entity))
