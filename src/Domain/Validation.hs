{-# LANGUAGE OverloadedStrings #-}

module Domain.Validation
  ( FieldError (..)
  , AppError (..)
  , requiredText
  , optionalText
  , parseOptionalText
  , parseOptionalEmail
  , parseDayField
  , parseOptionalDay
  , parseTimeField
  , parseOptionalTime
  , parsePositiveInt64
  , parsePositiveInt32
  , parseOptionalInt32
  , parseOptionalDouble
  , parseCheckbox
  , parseWeekdayField
  , parseCompetitionStatusField
  , validateTimeRange
  ) where

import Control.Applicative ((<|>))
import Data.Int (Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, TimeOfDay, defaultTimeLocale, parseTimeM)
import Text.Read (readMaybe)

data FieldError = FieldError
  { fieldName    :: Text
  , fieldMessage :: Text
  } deriving (Eq, Show)

data AppError
  = ValidationErrors [FieldError]
  | NotFoundError Text
  | ConflictError Text
  | DatabaseError Text
  | UnexpectedError Text
  deriving (Eq, Show)

requiredText :: Text -> Text -> Either FieldError Text
requiredText field value =
  let trimmed = T.strip value
  in if T.null trimmed
       then Left (FieldError field "Обов'язкове поле")
       else Right trimmed

optionalText :: Text -> Maybe Text
optionalText value =
  let trimmed = T.strip value
  in if T.null trimmed then Nothing else Just trimmed

parseOptionalText :: Text -> Text -> Either FieldError (Maybe Text)
parseOptionalText _ value = Right (optionalText value)

parseOptionalEmail :: Text -> Text -> Either FieldError (Maybe Text)
parseOptionalEmail field value =
  case optionalText value of
    Nothing -> Right Nothing
    Just email
      | T.any (== '@') email && T.any (== '.') email -> Right (Just email)
      | otherwise -> Left (FieldError field "Некоректна email-адреса")

parseDayField :: Text -> Text -> Either FieldError Day
parseDayField field value =
  case parseTimeM True defaultTimeLocale "%Y-%m-%d" (T.unpack (T.strip value)) of
    Just day -> Right day
    Nothing  -> Left (FieldError field "Очікується дата у форматі РРРР-ММ-ДД")

parseOptionalDay :: Text -> Text -> Either FieldError (Maybe Day)
parseOptionalDay _ "" = Right Nothing
parseOptionalDay field value =
  Just <$> parseDayField field value

parseTimeField :: Text -> Text -> Either FieldError TimeOfDay
parseTimeField field value =
  let raw = T.unpack (T.strip value)
      parsed =
        parseTimeM True defaultTimeLocale "%H:%M:%S" raw
          <|> parseTimeM True defaultTimeLocale "%H:%M" raw
  in case parsed of
       Just time -> Right time
       Nothing   -> Left (FieldError field "Очікується час у форматі ГГ:ХХ")

parseOptionalTime :: Text -> Text -> Either FieldError (Maybe TimeOfDay)
parseOptionalTime _ "" = Right Nothing
parseOptionalTime field value =
  Just <$> parseTimeField field value

parsePositiveInt64 :: Text -> Text -> Either FieldError Int64
parsePositiveInt64 field value =
  case readMaybe (T.unpack (T.strip value)) of
    Just number | number > 0 -> Right number
    _ -> Left (FieldError field "Очікується додатне ціле число")

parsePositiveInt32 :: Text -> Text -> Either FieldError Int32
parsePositiveInt32 field value =
  case readMaybe (T.unpack (T.strip value)) of
    Just number | number > 0 -> Right number
    _ -> Left (FieldError field "Очікується додатне ціле число")

parseOptionalInt32 :: Text -> Text -> Either FieldError (Maybe Int32)
parseOptionalInt32 _ "" = Right Nothing
parseOptionalInt32 field value =
  Just <$> parsePositiveInt32 field value

parseOptionalDouble :: Text -> Text -> Either FieldError (Maybe Double)
parseOptionalDouble _ "" = Right Nothing
parseOptionalDouble field value =
  case readMaybe (T.unpack (T.strip value)) of
    Just number | number >= 0 -> Right (Just number)
    _ -> Left (FieldError field "Очікується невід'ємне число")

parseCheckbox :: Text -> Text -> Bool
parseCheckbox _field value =
  T.toLower (T.strip value) `elem` ["on", "1", "true", "yes"]

parseWeekdayField :: Text -> Text -> Either FieldError Text
parseWeekdayField field value =
  case parseWeekdayValue (T.strip value) of
    Just weekday -> Right weekday
    Nothing      -> Left (FieldError field "Некоректний день тижня")
  where
    parseWeekdayValue :: Text -> Maybe Text
    parseWeekdayValue raw
      | raw `elem` ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] = Just raw
      | otherwise = Nothing

parseCompetitionStatusField :: Text -> Text -> Either FieldError Text
parseCompetitionStatusField field value =
  case T.strip value of
    status
      | status `elem` ["planned", "in_progress", "completed", "cancelled"] ->
          Right status
    _ -> Left (FieldError field "Некоректний статус змагання")

validateTimeRange :: TimeOfDay -> TimeOfDay -> Either FieldError ()
validateTimeRange start end
  | end <= start = Left (FieldError "end_time" "Час завершення має бути пізніше початку")
  | otherwise = Right ()
