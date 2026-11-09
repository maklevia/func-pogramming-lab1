{-# LANGUAGE OverloadedStrings #-}

module Web.Forms
  ( FormMap
  , formMapFromParams
  , formValue
  , parseFacultyInput
  , parseStudentInput
  , parseTeacherInput
  , parseSectionInput
  , parseScheduleInput
  , parseStudentSectionInput
  , parseCompetitionInput
  , parseParticipantInput
  ) where

import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Domain.Model
import Domain.Validation

type FormMap = Map Text Text

formMapFromParams :: [(Text, Text)] -> FormMap
formMapFromParams = Map.fromList

formValue :: Text -> FormMap -> Text
formValue key = Map.findWithDefault "" key

liftField :: Either FieldError a -> Either [FieldError] a
liftField = either (Left . pure) Right

parseOptionalIdValue :: Text -> Text -> Either FieldError (Maybe Int64)
parseOptionalIdValue field raw =
  case optionalText raw of
    Nothing -> Right Nothing
    Just value -> Just <$> parsePositiveInt64 field value

parseFacultyInput :: FormMap -> Either [FieldError] FacultyInput
parseFacultyInput form = do
  name <- liftField $ requiredText "name" (formValue "name" form)
  dean <- liftField $ parseOptionalText "dean" (formValue "dean" form)
  pure FacultyInput
    { inputFacultyName = name
    , inputFacultyDean = dean
    }

parseStudentInput :: FormMap -> Either [FieldError] StudentInput
parseStudentInput form = do
  facultyId <- liftField $ FacultyId <$> parsePositiveInt64 "faculty_id" (formValue "faculty_id" form)
  fullName <- liftField $ requiredText "full_name" (formValue "full_name" form)
  groupCode <- liftField $ requiredText "group_code" (formValue "group_code" form)
  birthDate <- liftField $ parseOptionalDay "birth_date" (formValue "birth_date" form)
  email <- liftField $ parseOptionalEmail "email" (formValue "email" form)
  phone <- liftField $ parseOptionalText "phone" (formValue "phone" form)
  pure StudentInput
    { inputStudentFacultyId = facultyId
    , inputStudentFullName = fullName
    , inputStudentGroup = groupCode
    , inputStudentBirthDate = birthDate
    , inputStudentEmail = email
    , inputStudentPhone = phone
    , inputStudentActive = parseCheckbox "active" (formValue "active" form)
    }

parseTeacherInput :: FormMap -> Either [FieldError] TeacherInput
parseTeacherInput form = do
  facultyId <- liftField $ FacultyId <$> parsePositiveInt64 "faculty_id" (formValue "faculty_id" form)
  fullName <- liftField $ requiredText "full_name" (formValue "full_name" form)
  department <- liftField $ requiredText "department" (formValue "department" form)
  position <- liftField $ requiredText "position" (formValue "position" form)
  email <- liftField $ parseOptionalEmail "email" (formValue "email" form)
  phone <- liftField $ parseOptionalText "phone" (formValue "phone" form)
  pure TeacherInput
    { inputTeacherFacultyId = facultyId
    , inputTeacherFullName = fullName
    , inputTeacherDepartment = department
    , inputTeacherPosition = position
    , inputTeacherEmail = email
    , inputTeacherPhone = phone
    , inputTeacherActive = parseCheckbox "active" (formValue "active" form)
    }

parseSectionInput :: FormMap -> Either [FieldError] SectionInput
parseSectionInput form = do
  name <- liftField $ requiredText "name" (formValue "name" form)
  sport <- liftField $ requiredText "sport" (formValue "sport" form)
  coachId <- liftField $
    fmap TeacherId <$> parseOptionalIdValue "coach_id" (formValue "coach_id" form)
  description <- liftField $ parseOptionalText "description" (formValue "description" form)
  pure SectionInput
    { inputSectionName = name
    , inputSectionSport = sport
    , inputSectionCoachId = coachId
    , inputSectionDescription = description
    , inputSectionActive = parseCheckbox "active" (formValue "active" form)
    }

parseScheduleInput :: FormMap -> Either [FieldError] ScheduleInput
parseScheduleInput form = do
  sectionId <- liftField $ SectionId <$> parsePositiveInt64 "section_id" (formValue "section_id" form)
  weekdayRaw <- liftField $ parseWeekdayField "weekday" (formValue "weekday" form)
  weekday <- case weekdayFromDB weekdayRaw of
    Just value -> Right value
    Nothing -> Left [FieldError "weekday" "Некоректний день тижня"]
  start <- liftField $ parseTimeField "start_time" (formValue "start_time" form)
  end <- liftField $ parseTimeField "end_time" (formValue "end_time" form)
  liftField $ validateTimeRange start end
  location <- liftField $ requiredText "location" (formValue "location" form)
  pure ScheduleInput
    { inputScheduleSectionId = sectionId
    , inputScheduleWeekday = weekday
    , inputScheduleStart = start
    , inputScheduleEnd = end
    , inputScheduleLocation = location
    }

parseStudentSectionInput :: FormMap -> Either [FieldError] StudentSectionInput
parseStudentSectionInput form = do
  studentId <- liftField $ StudentId <$> parsePositiveInt64 "student_id" (formValue "student_id" form)
  sectionId <- liftField $ SectionId <$> parsePositiveInt64 "section_id" (formValue "section_id" form)
  joinedAt <- liftField $ parseDayField "joined_at" (formValue "joined_at" form)
  pure StudentSectionInput
    { inputMembershipStudentId = studentId
    , inputMembershipSectionId = sectionId
    , inputMembershipJoinedAt = joinedAt
    , inputMembershipActive = parseCheckbox "active" (formValue "active" form)
    }

parseCompetitionInput :: FormMap -> Either [FieldError] CompetitionInput
parseCompetitionInput form = do
  title <- liftField $ requiredText "title" (formValue "title" form)
  sport <- liftField $ requiredText "sport" (formValue "sport" form)
  date <- liftField $ parseDayField "event_date" (formValue "event_date" form)
  startTime <- liftField $ parseOptionalTime "start_time" (formValue "start_time" form)
  location <- liftField $ requiredText "location" (formValue "location" form)
  statusRaw <- liftField $ parseCompetitionStatusField "status" (formValue "status" form)
  status <- case competitionStatusFromDB statusRaw of
    Just value -> Right value
    Nothing -> Left [FieldError "status" "Некоректний статус змагання"]
  teacherId <- liftField $
    fmap TeacherId <$> parseOptionalIdValue "responsible_teacher_id" (formValue "responsible_teacher_id" form)
  description <- liftField $ parseOptionalText "description" (formValue "description" form)
  pure CompetitionInput
    { inputCompetitionTitle = title
    , inputCompetitionSport = sport
    , inputCompetitionDate = date
    , inputCompetitionStartTime = startTime
    , inputCompetitionLocation = location
    , inputCompetitionStatus = status
    , inputCompetitionResponsibleTeacherId = teacherId
    , inputCompetitionDescription = description
    }

parseParticipantInput :: FormMap -> Either [FieldError] ParticipantInput
parseParticipantInput form = do
  competitionId <- liftField $ CompetitionId <$> parsePositiveInt64 "competition_id" (formValue "competition_id" form)
  studentId <- liftField $ StudentId <$> parsePositiveInt64 "student_id" (formValue "student_id" form)
  place <- liftField $ parseOptionalInt32 "place" (formValue "place" form)
  score <- liftField $ parseOptionalDouble "score" (formValue "score" form)
  pure ParticipantInput
    { inputParticipantCompetitionId = competitionId
    , inputParticipantStudentId = studentId
    , inputParticipantPlace = place
    , inputParticipantScore = score
    }
