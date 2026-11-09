{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module DB.Queries
  ( StudentListItem
  , TeacherListItem
  , SectionListItem
  , CompetitionListItem
  , SectionDetails (..)
  , CompetitionDetails (..)
  , DashboardStats (..)
  , listFaculties
  , listStudents
  , listTeachers
  , listSections
  , listCompetitions
  , getSectionDetails
  , getCompetitionDetails
  , dashboardStats
  , facultyOptions
  , teacherOptions
  , studentOptions
  , sectionOptions
  , competitionOptions
  ) where

import Data.Int (Int64)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.Time (Day)
import Database.MySQL.Base
import Database.MySQL.Field (Field (..))

import DB.Entity
import DB.Instances ()
import DB.Repository
import Domain.Model
import Domain.Validation (AppError (..))

type StudentListItem = (Student, Text)
type TeacherListItem = (Teacher, Text)
type SectionListItem = (Section, Maybe Text, Int64, Int64)
type CompetitionListItem = (Competition, Maybe Text, Int64)

data SectionDetails = SectionDetails
  { detailSection  :: Section
  , detailCoach    :: Maybe Teacher
  , detailSchedule :: [ScheduleEntry]
  , detailStudents :: [(StudentSection, Text)]
  } deriving (Eq, Show)

data CompetitionDetails = CompetitionDetails
  { detailCompetition  :: Competition
  , detailTeacher      :: Maybe Teacher
  , detailParticipants :: [(CompetitionParticipant, Text)]
  } deriving (Eq, Show)

data DashboardStats = DashboardStats
  { statStudentsCount     :: Int64
  , statTeachersCount     :: Int64
  , statSectionsCount     :: Int64
  , statCompetitionsCount :: Int64
  , statUpcoming          :: [Competition]
  } deriving (Eq, Show)

listFaculties :: Pool MySQLConn -> IO (Either AppError [Faculty])
listFaculties = findAll @Faculty

listStudents :: Pool MySQLConn -> IO (Either AppError [StudentListItem])
listStudents pool = do
  rowsResult <-
    runQuery pool
      "SELECT s.id, s.faculty_id, s.full_name, s.group_code, s.birth_date, \
      \s.email, s.phone, s.active, f.name \
      \FROM students s JOIN faculties f ON f.id = s.faculty_id \
      \ORDER BY s.full_name" []
  pure (rowsResult >>= traverse decodeStudentRow)

listTeachers :: Pool MySQLConn -> IO (Either AppError [TeacherListItem])
listTeachers pool = do
  rowsResult <-
    runQuery pool
      "SELECT t.id, t.faculty_id, t.full_name, t.department, t.position, \
      \t.email, t.phone, t.active, f.name \
      \FROM teachers t JOIN faculties f ON f.id = t.faculty_id \
      \ORDER BY t.full_name" []
  pure (rowsResult >>= traverse decodeTeacherRow)

listSections :: Pool MySQLConn -> IO (Either AppError [SectionListItem])
listSections pool = do
  rowsResult <-
    runQuery pool
      "SELECT sec.id, sec.name, sec.sport, sec.coach_id, sec.description, sec.active, \
      \t.full_name, \
      \CAST((SELECT COUNT(*) FROM section_schedule sch WHERE sch.section_id = sec.id) AS SIGNED), \
      \CAST((SELECT COUNT(*) FROM student_sections ss WHERE ss.section_id = sec.id AND ss.active = 1) AS SIGNED) \
      \FROM sections sec LEFT JOIN teachers t ON t.id = sec.coach_id \
      \ORDER BY sec.name" []
  pure (rowsResult >>= traverse decodeSectionRow)

listCompetitions :: Pool MySQLConn -> IO (Either AppError [CompetitionListItem])
listCompetitions pool = do
  rowsResult <-
    runQuery pool
      "SELECT c.id, c.title, c.sport, c.event_date, c.start_time, c.location, \
      \c.status, c.responsible_teacher_id, c.description, t.full_name, \
      \CAST((SELECT COUNT(*) FROM competition_participants cp WHERE cp.competition_id = c.id) AS SIGNED) \
      \FROM competitions c LEFT JOIN teachers t ON t.id = c.responsible_teacher_id \
      \ORDER BY c.event_date DESC, c.id DESC" []
  pure (rowsResult >>= traverse decodeCompetitionRow)

getSectionDetails :: Pool MySQLConn -> SectionId -> IO (Either AppError (Maybe SectionDetails))
getSectionDetails pool sectionId = do
  sectionResult <- findById @Section pool (unSectionId sectionId)
  case sectionResult of
    Left err -> pure (Left err)
    Right Nothing -> pure (Right Nothing)
    Right (Just section) -> do
      coachResult <- loadCoach (sectionCoachId section)
      scheduleResult <-
        runQuery pool
          "SELECT id, section_id, weekday, start_time, end_time, location \
          \FROM section_schedule WHERE section_id = ? \
          \ORDER BY FIELD(weekday, 'Mon','Tue','Wed','Thu','Fri','Sat','Sun'), start_time"
          [toField (unSectionId sectionId)]
      studentsResult <-
        runQuery pool
          "SELECT ss.id, ss.student_id, ss.section_id, ss.joined_at, ss.active, s.full_name \
          \FROM student_sections ss JOIN students s ON s.id = ss.student_id \
          \WHERE ss.section_id = ? ORDER BY s.full_name"
          [toField (unSectionId sectionId)]
      pure $ do
        coach <- coachResult
        scheduleRows <- scheduleResult
        studentRows <- studentsResult
        schedule <- traverse fromRow scheduleRows
        students <- traverse decodeMembershipRow studentRows
        pure $ Just SectionDetails
          { detailSection = section
          , detailCoach = coach
          , detailSchedule = schedule
          , detailStudents = students
          }
  where
    loadCoach Nothing = pure (Right Nothing)
    loadCoach (Just teacherId) =
      findById @Teacher pool (unTeacherId teacherId)

getCompetitionDetails :: Pool MySQLConn -> CompetitionId -> IO (Either AppError (Maybe CompetitionDetails))
getCompetitionDetails pool competitionId = do
  competitionResult <- findById @Competition pool (unCompetitionId competitionId)
  case competitionResult of
    Left err -> pure (Left err)
    Right Nothing -> pure (Right Nothing)
    Right (Just competition) -> do
      teacherResult <- loadTeacher (competitionResponsibleTeacherId competition)
      participantsResult <-
        runQuery pool
          "SELECT cp.id, cp.competition_id, cp.student_id, cp.place, cp.score, s.full_name \
          \FROM competition_participants cp JOIN students s ON s.id = cp.student_id \
          \WHERE cp.competition_id = ? \
          \ORDER BY cp.place IS NULL, cp.place, s.full_name"
          [toField (unCompetitionId competitionId)]
      pure $ do
        teacher <- teacherResult
        participantRows <- participantsResult
        participants <- traverse decodeParticipantRow participantRows
        pure $ Just CompetitionDetails
          { detailCompetition = competition
          , detailTeacher = teacher
          , detailParticipants = participants
          }
  where
    loadTeacher Nothing = pure (Right Nothing)
    loadTeacher (Just teacherId) =
      findById @Teacher pool (unTeacherId teacherId)

dashboardStats :: Pool MySQLConn -> Day -> IO (Either AppError DashboardStats)
dashboardStats pool today = do
  studentsCount <- countAll @Student pool
  teachersCount <- countAll @Teacher pool
  sectionsCount <- countAll @Section pool
  competitionsCount <- countAll @Competition pool
  upcomingResult <-
    runQuery pool
      "SELECT id, title, sport, event_date, start_time, location, status, \
      \responsible_teacher_id, description \
      \FROM competitions WHERE event_date >= ? AND status <> 'cancelled' \
      \ORDER BY event_date, start_time LIMIT 5"
      [toField today]
  pure $ do
    students <- studentsCount
    teachers <- teachersCount
    sections <- sectionsCount
    competitions <- competitionsCount
    upcomingRows <- upcomingResult
    upcoming <- traverse fromRow upcomingRows
    pure DashboardStats
      { statStudentsCount = students
      , statTeachersCount = teachers
      , statSectionsCount = sections
      , statCompetitionsCount = competitions
      , statUpcoming = upcoming
      }

facultyOptions :: Pool MySQLConn -> IO (Either AppError [(Int64, Text)])
facultyOptions pool =
  optionsQuery pool "SELECT id, name FROM faculties ORDER BY name"

teacherOptions :: Pool MySQLConn -> IO (Either AppError [(Int64, Text)])
teacherOptions pool =
  optionsQuery pool "SELECT id, full_name FROM teachers WHERE active = 1 ORDER BY full_name"

studentOptions :: Pool MySQLConn -> IO (Either AppError [(Int64, Text)])
studentOptions pool =
  optionsQuery pool "SELECT id, full_name FROM students WHERE active = 1 ORDER BY full_name"

sectionOptions :: Pool MySQLConn -> IO (Either AppError [(Int64, Text)])
sectionOptions pool =
  optionsQuery pool "SELECT id, CONCAT(name, ' — ', sport) FROM sections WHERE active = 1 ORDER BY name"

competitionOptions :: Pool MySQLConn -> IO (Either AppError [(Int64, Text)])
competitionOptions pool =
  optionsQuery pool "SELECT id, title FROM competitions ORDER BY event_date DESC"

optionsQuery :: Pool MySQLConn -> Query -> IO (Either AppError [(Int64, Text)])
optionsQuery pool queryText = do
  rowsResult <- runQuery pool queryText []
  pure (rowsResult >>= traverse decodeOptionRow)

decodeOptionRow :: [MySQLValue] -> Either AppError (Int64, Text)
decodeOptionRow row = case row of
  [idV, labelV] -> (,) <$> decodeField "id" idV <*> decodeField "label" labelV
  _ -> Left (UnexpectedError "Неправильна кількість колонок для довідника")

decodeStudentRow :: [MySQLValue] -> Either AppError StudentListItem
decodeStudentRow row = case row of
  [idV, facultyV, nameV, groupV, birthV, emailV, phoneV, activeV, facultyNameV] -> do
    student <- fromRow [idV, facultyV, nameV, groupV, birthV, emailV, phoneV, activeV]
    facultyName <- decodeField "faculty_name" facultyNameV
    pure (student, facultyName)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для студента")

decodeTeacherRow :: [MySQLValue] -> Either AppError TeacherListItem
decodeTeacherRow row = case row of
  [idV, facultyV, nameV, departmentV, positionV, emailV, phoneV, activeV, facultyNameV] -> do
    teacher <- fromRow [idV, facultyV, nameV, departmentV, positionV, emailV, phoneV, activeV]
    facultyName <- decodeField "faculty_name" facultyNameV
    pure (teacher, facultyName)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для викладача")

decodeSectionRow :: [MySQLValue] -> Either AppError SectionListItem
decodeSectionRow row = case row of
  [idV, nameV, sportV, coachV, descriptionV, activeV, coachNameV, scheduleCountV, memberCountV] -> do
    section <- fromRow [idV, nameV, sportV, coachV, descriptionV, activeV]
    coachName <- decodeField "coach_name" coachNameV
    scheduleCount <- decodeFlexibleInt64 "schedule_count" scheduleCountV
    memberCount <- decodeFlexibleInt64 "member_count" memberCountV
    pure (section, coachName, scheduleCount, memberCount)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для секції")

decodeCompetitionRow :: [MySQLValue] -> Either AppError CompetitionListItem
decodeCompetitionRow row = case row of
  [ idV, titleV, sportV, dateV, startV, locationV, statusV, teacherV, descriptionV
    , teacherNameV, participantCountV
    ] -> do
      competition <- fromRow
        [idV, titleV, sportV, dateV, startV, locationV, statusV, teacherV, descriptionV]
      teacherName <- decodeField "teacher_name" teacherNameV
      participantCount <- decodeFlexibleInt64 "participant_count" participantCountV
      pure (competition, teacherName, participantCount)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для змагання")

decodeMembershipRow :: [MySQLValue] -> Either AppError (StudentSection, Text)
decodeMembershipRow row = case row of
  [idV, studentV, sectionV, joinedV, activeV, studentNameV] -> do
    membership <- fromRow [idV, studentV, sectionV, joinedV, activeV]
    studentName <- decodeField "student_name" studentNameV
    pure (membership, studentName)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для участі студента")

decodeParticipantRow :: [MySQLValue] -> Either AppError (CompetitionParticipant, Text)
decodeParticipantRow row = case row of
  [idV, competitionV, studentV, placeV, scoreV, studentNameV] -> do
    participant <- fromRow [idV, competitionV, studentV, placeV, scoreV]
    studentName <- decodeField "student_name" studentNameV
    pure (participant, studentName)
  _ -> Left (UnexpectedError "Неправильна кількість колонок для учасника змагання")
