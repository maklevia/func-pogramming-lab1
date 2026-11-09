{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module DB.Repository
  ( findAll
  , findById
  , insert
  , update
  , delete
  , countAll
  , pingDB
  , runQuery
  ) where

import Control.Exception (SomeAsyncException (..), SomeException, fromException, throwIO, try)
import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Pool (Pool, withResource)
import Data.Proxy (Proxy (..))
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Data.Word (Word16)
import Database.MySQL.Base
import Database.MySQL.Field (Field (..))
import qualified System.IO.Streams as Streams

import DB.Entity
import Domain.Validation (AppError (..))

findAll :: forall a. Entity a => Pool MySQLConn -> IO (Either AppError [a])
findAll pool = do
  let queryText =
        "SELECT id, "
          <> T.intercalate ", " (columns (Proxy @a))
          <> " FROM "
          <> tableName (Proxy @a)
          <> " ORDER BY id"
  rowsResult <- runQuery pool (toQuery queryText) []
  pure (rowsResult >>= traverse fromRow)

findById :: forall a. Entity a => Pool MySQLConn -> Int64 -> IO (Either AppError (Maybe a))
findById pool ident = do
  let queryText =
        "SELECT id, "
          <> T.intercalate ", " (columns (Proxy @a))
          <> " FROM "
          <> tableName (Proxy @a)
          <> " WHERE id = ?"
  rowsResult <- runQuery pool (toQuery queryText) [toField ident]
  pure $ rowsResult >>= \case
    [] -> Right Nothing
    [row] -> Just <$> fromRow row
    _ -> Left (UnexpectedError "Запит за id повернув більше одного рядка")

insert :: forall a. Entity a => Pool MySQLConn -> a -> IO (Either AppError Int64)
insert pool entity = do
  let entityColumns = columns (Proxy @a)
      placeholders = T.intercalate ", " (replicate (length entityColumns) "?")
      queryText =
        "INSERT INTO "
          <> tableName (Proxy @a)
          <> " ("
          <> T.intercalate ", " entityColumns
          <> ") VALUES ("
          <> placeholders
          <> ")"
  result <- tryDB $ withResource pool $ \conn -> execute conn (toQuery queryText) (toRow entity)
  pure $ case result of
    Left err -> Left err
    Right ok -> Right (fromIntegral (okLastInsertID ok))

update :: forall a. Entity a => Pool MySQLConn -> a -> IO (Either AppError ())
update pool entity = do
  let entityColumns = columns (Proxy @a)
      assignments = T.intercalate ", " [column <> " = ?" | column <- entityColumns]
      queryText =
        "UPDATE "
          <> tableName (Proxy @a)
          <> " SET "
          <> assignments
          <> " WHERE id = ?"
  result <-
    tryDB $
      withResource pool $ \conn ->
        execute conn (toQuery queryText) (toRow entity <> [toField (entityId entity)])
  pure (() <$ result)

delete :: forall a. Entity a => Pool MySQLConn -> Int64 -> IO (Either AppError ())
delete pool ident = do
  let queryText = "DELETE FROM " <> tableName (Proxy @a) <> " WHERE id = ?"
  result <- tryDB $ withResource pool $ \conn -> execute conn (toQuery queryText) [toField ident]
  pure (() <$ result)

countAll :: forall a. Entity a => Pool MySQLConn -> IO (Either AppError Int64)
countAll pool = do
  let queryText = "SELECT CAST(COUNT(*) AS SIGNED) FROM " <> tableName (Proxy @a)
  rowsResult <- runQuery pool (toQuery queryText) []
  pure $ rowsResult >>= \case
    [[value]] -> decodeFlexibleInt64 "count" value
    _ -> Left (UnexpectedError "Не вдалося порахувати кількість записів")

pingDB :: Pool MySQLConn -> IO (Either AppError ())
pingDB pool = do
  result <- tryDB $ withResource pool $ \conn -> ping conn
  pure (() <$ result)

toQuery :: Text -> Query
toQuery = fromString . T.unpack

runQuery :: Pool MySQLConn -> Query -> [MySQLValue] -> IO (Either AppError [[MySQLValue]])
runQuery pool queryText params =
  tryDB $
    withResource pool $ \conn -> do
      (_, rows) <- query conn queryText params
      Streams.toList rows

tryDB :: forall a. IO a -> IO (Either AppError a)
tryDB action = do
  result <- try action :: IO (Either SomeException a)
  case result of
    Left err ->
      case fromException err :: Maybe SomeAsyncException of
        Just (SomeAsyncException _) -> throwIO err
        Nothing ->
          case fromException err :: Maybe ERRException of
            Just (ERRException dbErr) ->
              pure (Left (mapDatabaseError (errCode dbErr) (errMsg dbErr)))
            Nothing -> pure (Left (DatabaseError (T.pack (show err))))
    Right value -> pure (Right value)

mapDatabaseError :: Word16 -> ByteString -> AppError
mapDatabaseError code message
  | code == 1062 =
      ConflictError "Такий запис уже існує. Перевірте унікальні поля."
  | code `elem` [1451, 1452] =
      ConflictError "Порушено зв'язок з іншими записами. Спочатку виправте пов'язані дані."
  | code == 3819 =
      ConflictError "Дані не пройшли перевірку на рівні бази даних."
  | otherwise =
      DatabaseError (T.pack (show code) <> ": " <> decodeUtf8With lenientDecode message)
