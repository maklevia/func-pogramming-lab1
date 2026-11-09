{-# LANGUAGE OverloadedStrings #-}

module Domain.Model
  ( FacultyId (..)
  , StudentId (..)
  , TeacherId (..)
  , SectionId (..)
  , ScheduleId (..)
  , StudentSectionId (..)
  , CompetitionId (..)
  , ParticipantId (..)
  , Weekday (..)
  , CompetitionStatus (..)
  , Faculty (..)
  , Student (..)
  , Teacher (..)
  , Section (..)
  , ScheduleEntry (..)
  , StudentSection (..)
  , Competition (..)
  , CompetitionParticipant (..)
  , FacultyInput (..)
  , StudentInput (..)
  , TeacherInput (..)
  , SectionInput (..)
  , ScheduleInput (..)
  , StudentSectionInput (..)
  , CompetitionInput (..)
  , ParticipantInput (..)
  , weekdayToDB
  , weekdayFromDB
  , weekdayLabel
  , weekdayOptions
  , competitionStatusToDB
  , competitionStatusFromDB
  , competitionStatusLabel
  , competitionStatusOptions
  ) where

import Data.Int (Int32, Int64)
import Data.Text (Text)
import Data.Time (Day, TimeOfDay)

newtype FacultyId = FacultyId { unFacultyId :: Int64 }
  deriving (Eq, Ord, Show)

newtype StudentId = StudentId { unStudentId :: Int64 }
  deriving (Eq, Ord, Show)

newtype TeacherId = TeacherId { unTeacherId :: Int64 }
  deriving (Eq, Ord, Show)

newtype SectionId = SectionId { unSectionId :: Int64 }
  deriving (Eq, Ord, Show)

newtype ScheduleId = ScheduleId { unScheduleId :: Int64 }
  deriving (Eq, Ord, Show)

newtype StudentSectionId = StudentSectionId { unStudentSectionId :: Int64 }
  deriving (Eq, Ord, Show)

newtype CompetitionId = CompetitionId { unCompetitionId :: Int64 }
  deriving (Eq, Ord, Show)

newtype ParticipantId = ParticipantId { unParticipantId :: Int64 }
  deriving (Eq, Ord, Show)

data Weekday
  = Monday
  | Tuesday
  | Wednesday
  | Thursday
  | Friday
  | Saturday
  | Sunday
  deriving (Eq, Ord, Show, Enum, Bounded)

data CompetitionStatus
  = Planned
  | InProgress
  | Completed
  | Cancelled
  deriving (Eq, Ord, Show, Enum, Bounded)

data Faculty = Faculty
  { facultyId   :: FacultyId
  , facultyName :: Text
  , facultyDean :: Maybe Text
  } deriving (Eq, Show)

data Student = Student
  { studentId        :: StudentId
  , studentFacultyId :: FacultyId
  , studentFullName  :: Text
  , studentGroup     :: Text
  , studentBirthDate :: Maybe Day
  , studentEmail     :: Maybe Text
  , studentPhone     :: Maybe Text
  , studentActive    :: Bool
  } deriving (Eq, Show)

data Teacher = Teacher
  { teacherId         :: TeacherId
  , teacherFacultyId  :: FacultyId
  , teacherFullName   :: Text
  , teacherDepartment :: Text
  , teacherPosition   :: Text
  , teacherEmail      :: Maybe Text
  , teacherPhone      :: Maybe Text
  , teacherActive     :: Bool
  } deriving (Eq, Show)

data Section = Section
  { sectionId          :: SectionId
  , sectionName        :: Text
  , sectionSport       :: Text
  , sectionCoachId     :: Maybe TeacherId
  , sectionDescription :: Maybe Text
  , sectionActive      :: Bool
  } deriving (Eq, Show)

data ScheduleEntry = ScheduleEntry
  { scheduleId        :: ScheduleId
  , scheduleSectionId :: SectionId
  , scheduleWeekday   :: Weekday
  , scheduleStart     :: TimeOfDay
  , scheduleEnd       :: TimeOfDay
  , scheduleLocation  :: Text
  } deriving (Eq, Show)

data StudentSection = StudentSection
  { membershipId        :: StudentSectionId
  , membershipStudentId :: StudentId
  , membershipSectionId :: SectionId
  , membershipJoinedAt  :: Day
  , membershipActive    :: Bool
  } deriving (Eq, Show)

data Competition = Competition
  { competitionId                   :: CompetitionId
  , competitionTitle                :: Text
  , competitionSport                :: Text
  , competitionDate                 :: Day
  , competitionStartTime            :: Maybe TimeOfDay
  , competitionLocation             :: Text
  , competitionStatus               :: CompetitionStatus
  , competitionResponsibleTeacherId :: Maybe TeacherId
  , competitionDescription          :: Maybe Text
  } deriving (Eq, Show)

data CompetitionParticipant = CompetitionParticipant
  { participantId            :: ParticipantId
  , participantCompetitionId :: CompetitionId
  , participantStudentId     :: StudentId
  , participantPlace         :: Maybe Int32
  , participantScore         :: Maybe Double
  } deriving (Eq, Show)

-- | Validated data coming from the web forms.
data FacultyInput = FacultyInput
  { inputFacultyName :: Text
  , inputFacultyDean :: Maybe Text
  } deriving (Eq, Show)

data StudentInput = StudentInput
  { inputStudentFacultyId :: FacultyId
  , inputStudentFullName  :: Text
  , inputStudentGroup     :: Text
  , inputStudentBirthDate :: Maybe Day
  , inputStudentEmail     :: Maybe Text
  , inputStudentPhone     :: Maybe Text
  , inputStudentActive    :: Bool
  } deriving (Eq, Show)

data TeacherInput = TeacherInput
  { inputTeacherFacultyId  :: FacultyId
  , inputTeacherFullName   :: Text
  , inputTeacherDepartment :: Text
  , inputTeacherPosition   :: Text
  , inputTeacherEmail      :: Maybe Text
  , inputTeacherPhone      :: Maybe Text
  , inputTeacherActive     :: Bool
  } deriving (Eq, Show)

data SectionInput = SectionInput
  { inputSectionName        :: Text
  , inputSectionSport       :: Text
  , inputSectionCoachId     :: Maybe TeacherId
  , inputSectionDescription :: Maybe Text
  , inputSectionActive      :: Bool
  } deriving (Eq, Show)

data ScheduleInput = ScheduleInput
  { inputScheduleSectionId :: SectionId
  , inputScheduleWeekday   :: Weekday
  , inputScheduleStart     :: TimeOfDay
  , inputScheduleEnd       :: TimeOfDay
  , inputScheduleLocation  :: Text
  } deriving (Eq, Show)

data StudentSectionInput = StudentSectionInput
  { inputMembershipStudentId :: StudentId
  , inputMembershipSectionId :: SectionId
  , inputMembershipJoinedAt  :: Day
  , inputMembershipActive    :: Bool
  } deriving (Eq, Show)

data CompetitionInput = CompetitionInput
  { inputCompetitionTitle                :: Text
  , inputCompetitionSport                :: Text
  , inputCompetitionDate                 :: Day
  , inputCompetitionStartTime            :: Maybe TimeOfDay
  , inputCompetitionLocation             :: Text
  , inputCompetitionStatus               :: CompetitionStatus
  , inputCompetitionResponsibleTeacherId :: Maybe TeacherId
  , inputCompetitionDescription          :: Maybe Text
  } deriving (Eq, Show)

data ParticipantInput = ParticipantInput
  { inputParticipantCompetitionId :: CompetitionId
  , inputParticipantStudentId     :: StudentId
  , inputParticipantPlace         :: Maybe Int32
  , inputParticipantScore         :: Maybe Double
  } deriving (Eq, Show)

weekdayToDB :: Weekday -> Text
weekdayToDB Monday    = "Mon"
weekdayToDB Tuesday   = "Tue"
weekdayToDB Wednesday = "Wed"
weekdayToDB Thursday  = "Thu"
weekdayToDB Friday    = "Fri"
weekdayToDB Saturday  = "Sat"
weekdayToDB Sunday    = "Sun"

weekdayFromDB :: Text -> Maybe Weekday
weekdayFromDB "Mon" = Just Monday
weekdayFromDB "Tue" = Just Tuesday
weekdayFromDB "Wed" = Just Wednesday
weekdayFromDB "Thu" = Just Thursday
weekdayFromDB "Fri" = Just Friday
weekdayFromDB "Sat" = Just Saturday
weekdayFromDB "Sun" = Just Sunday
weekdayFromDB _     = Nothing

weekdayLabel :: Weekday -> Text
weekdayLabel Monday    = "Понеділок"
weekdayLabel Tuesday   = "Вівторок"
weekdayLabel Wednesday = "Середа"
weekdayLabel Thursday  = "Четвер"
weekdayLabel Friday    = "П'ятниця"
weekdayLabel Saturday  = "Субота"
weekdayLabel Sunday    = "Неділя"

weekdayOptions :: [(Text, Text)]
weekdayOptions =
  [ (weekdayToDB day, weekdayLabel day)
  | day <- [minBound .. maxBound]
  ]

competitionStatusToDB :: CompetitionStatus -> Text
competitionStatusToDB Planned    = "planned"
competitionStatusToDB InProgress = "in_progress"
competitionStatusToDB Completed  = "completed"
competitionStatusToDB Cancelled  = "cancelled"

competitionStatusFromDB :: Text -> Maybe CompetitionStatus
competitionStatusFromDB "planned"     = Just Planned
competitionStatusFromDB "in_progress" = Just InProgress
competitionStatusFromDB "completed"   = Just Completed
competitionStatusFromDB "cancelled"   = Just Cancelled
competitionStatusFromDB _             = Nothing

competitionStatusLabel :: CompetitionStatus -> Text
competitionStatusLabel Planned    = "Заплановано"
competitionStatusLabel InProgress = "У процесі"
competitionStatusLabel Completed  = "Завершено"
competitionStatusLabel Cancelled  = "Скасовано"

competitionStatusOptions :: [(Text, Text)]
competitionStatusOptions =
  [ (competitionStatusToDB status, competitionStatusLabel status)
  | status <- [minBound .. maxBound]
  ]
