{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Either (isLeft)
import qualified Data.Map.Strict as Map
import Data.Time.Calendar (fromGregorian)
import Data.Time.LocalTime (TimeOfDay (..))
import Database.MySQL.Field (toField)

import DB.Entity (Entity (..))
import DB.Instances ()
import Domain.Model
import Domain.Validation
import Web.Forms (FormMap, parseFacultyInput, parseStudentInput)

main :: IO ()
main = do
  check "requiredText rejects blank input" $
    requiredText "name" "   " == Left (FieldError "name" "Обов'язкове поле")

  check "requiredText trims valid input" $
    requiredText "name" "  Test  " == Right "Test"

  check "parseDayField accepts ISO date" $
    parseDayField "birth_date" "2005-05-05" == Right (fromGregorian 2005 5 5)

  check "parseDayField rejects dot-separated date" $
    isLeft (parseDayField "birth_date" "05.05.2005")

  check "parseTimeField accepts HH:MM" $
    parseTimeField "start_time" "10:30" == Right (TimeOfDay 10 30 0)

  check "validateTimeRange accepts ordered times" $
    validateTimeRange (TimeOfDay 10 0 0) (TimeOfDay 11 0 0) == Right ()

  check "validateTimeRange rejects equal times" $
    isLeft (validateTimeRange (TimeOfDay 10 0 0) (TimeOfDay 10 0 0))

  check "parseFacultyInput rejects blank name" $
    case parseFacultyInput (Map.fromList [("name", "")]) of
      Left errors -> any ((== "name") . fieldName) errors
      Right _ -> False

  check "parseStudentInput accepts valid form" $
    case parseStudentInput validStudentForm of
      Right input -> inputStudentFullName input == "Test Student"
      Left _ -> False

  check "parseStudentInput rejects invalid email" $
    case parseStudentInput (Map.insert "email" "bad" validStudentForm) of
      Left errors -> any ((== "email") . fieldName) errors
      Right _ -> False

  check "parseStudentInput rejects blank name" $
    case parseStudentInput (Map.insert "full_name" "" validStudentForm) of
      Left errors -> any ((== "full_name") . fieldName) errors
      Right _ -> False

  let student = Student
        { studentId = StudentId 7
        , studentFacultyId = FacultyId 1
        , studentFullName = "Test Student"
        , studentGroup = "G-1"
        , studentBirthDate = Just (fromGregorian 2005 1 2)
        , studentEmail = Just "test@example.com"
        , studentPhone = Nothing
        , studentActive = True
        }
  check "Student Entity roundtrip" $
    fromRow (toField (entityId student) : toRow student) == Right student

  let section = Section
        { sectionId = SectionId 5
        , sectionName = "Test Section"
        , sectionSport = "Football"
        , sectionCoachId = Just (TeacherId 4)
        , sectionDescription = Just "Description"
        , sectionActive = True
        }
  check "Section Entity roundtrip" $
    fromRow (toField (entityId section) : toRow section) == Right section

  let competition = Competition
        { competitionId = CompetitionId 4
        , competitionTitle = "Test Competition"
        , competitionSport = "Football"
        , competitionDate = fromGregorian 2027 2 2
        , competitionStartTime = Just (TimeOfDay 12 0 0)
        , competitionLocation = "Hall"
        , competitionStatus = Planned
        , competitionResponsibleTeacherId = Just (TeacherId 4)
        , competitionDescription = Just "Description"
        }
  check "Competition Entity roundtrip" $
    fromRow (toField (entityId competition) : toRow competition) == Right competition

  let participant = CompetitionParticipant
        { participantId = ParticipantId 6
        , participantCompetitionId = CompetitionId 4
        , participantStudentId = StudentId 7
        , participantPlace = Just 2
        , participantScore = Just 7.5
        }
  check "CompetitionParticipant Entity roundtrip" $
    fromRow (toField (entityId participant) : toRow participant) == Right participant

  check "Student fromRow rejects wrong column count" $
    isLeft (fromRow [] :: Either AppError Student)

  putStrLn "All pure tests passed."

check :: String -> Bool -> IO ()
check label ok =
  if ok
    then putStrLn ("PASS " <> label)
    else fail ("FAIL " <> label)

validStudentForm :: FormMap
validStudentForm = Map.fromList
  [ ("faculty_id", "1")
  , ("full_name", "Test Student")
  , ("group_code", "G-1")
  , ("birth_date", "2005-01-02")
  , ("email", "test@example.com")
  , ("phone", "")
  , ("active", "on")
  ]
