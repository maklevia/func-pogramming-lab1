{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- The Entity instances live in the persistence adapter on purpose: the
-- domain types stay independent from MySQL, while all row-mapping instances
-- are kept in one place instead of being scattered across modules.
module DB.Instances () where

import Database.MySQL.Field (Field (..))

import DB.Entity
import Domain.Model

instance Entity Faculty where
  tableName _ = "faculties"
  columns _ = ["name", "dean"]
  entityId = unFacultyId . facultyId
  toRow faculty =
    [ toField (facultyName faculty)
    , toField (facultyDean faculty)
    ]
  fromRow row = case row of
    [idV, nameV, deanV] -> do
      ident <- FacultyId <$> decodeField "id" idV
      name <- decodeField "name" nameV
      dean <- decodeField "dean" deanV
      pure Faculty
        { facultyId = ident
        , facultyName = name
        , facultyDean = dean
        }
    _ -> columnsMismatch "Faculty"

instance Entity Student where
  tableName _ = "students"
  columns _ =
    [ "faculty_id"
    , "full_name"
    , "group_code"
    , "birth_date"
    , "email"
    , "phone"
    , "active"
    ]
  entityId = unStudentId . studentId
  toRow student =
    [ toField (unFacultyId (studentFacultyId student))
    , toField (studentFullName student)
    , toField (studentGroup student)
    , toField (studentBirthDate student)
    , toField (studentEmail student)
    , toField (studentPhone student)
    , toField (studentActive student)
    ]
  fromRow row = case row of
    [idV, facultyV, nameV, groupV, birthV, emailV, phoneV, activeV] -> do
      ident <- StudentId <$> decodeField "id" idV
      faculty <- FacultyId <$> decodeField "faculty_id" facultyV
      name <- decodeField "full_name" nameV
      groupCode <- decodeField "group_code" groupV
      birth <- decodeField "birth_date" birthV
      email <- decodeField "email" emailV
      phone <- decodeField "phone" phoneV
      active <- decodeField "active" activeV
      pure Student
        { studentId = ident
        , studentFacultyId = faculty
        , studentFullName = name
        , studentGroup = groupCode
        , studentBirthDate = birth
        , studentEmail = email
        , studentPhone = phone
        , studentActive = active
        }
    _ -> columnsMismatch "Student"

instance Entity Teacher where
  tableName _ = "teachers"
  columns _ =
    [ "faculty_id"
    , "full_name"
    , "department"
    , "position"
    , "email"
    , "phone"
    , "active"
    ]
  entityId = unTeacherId . teacherId
  toRow teacher =
    [ toField (unFacultyId (teacherFacultyId teacher))
    , toField (teacherFullName teacher)
    , toField (teacherDepartment teacher)
    , toField (teacherPosition teacher)
    , toField (teacherEmail teacher)
    , toField (teacherPhone teacher)
    , toField (teacherActive teacher)
    ]
  fromRow row = case row of
    [idV, facultyV, nameV, departmentV, positionV, emailV, phoneV, activeV] -> do
      ident <- TeacherId <$> decodeField "id" idV
      faculty <- FacultyId <$> decodeField "faculty_id" facultyV
      name <- decodeField "full_name" nameV
      department <- decodeField "department" departmentV
      position <- decodeField "position" positionV
      email <- decodeField "email" emailV
      phone <- decodeField "phone" phoneV
      active <- decodeField "active" activeV
      pure Teacher
        { teacherId = ident
        , teacherFacultyId = faculty
        , teacherFullName = name
        , teacherDepartment = department
        , teacherPosition = position
        , teacherEmail = email
        , teacherPhone = phone
        , teacherActive = active
        }
    _ -> columnsMismatch "Teacher"

instance Entity Section where
  tableName _ = "sections"
  columns _ = ["name", "sport", "coach_id", "description", "active"]
  entityId = unSectionId . sectionId
  toRow section =
    [ toField (sectionName section)
    , toField (sectionSport section)
    , toField (fmap unTeacherId (sectionCoachId section))
    , toField (sectionDescription section)
    , toField (sectionActive section)
    ]
  fromRow row = case row of
    [idV, nameV, sportV, coachV, descriptionV, activeV] -> do
      ident <- SectionId <$> decodeField "id" idV
      name <- decodeField "name" nameV
      sport <- decodeField "sport" sportV
      coach <- fmap TeacherId <$> decodeField "coach_id" coachV
      description <- decodeField "description" descriptionV
      active <- decodeField "active" activeV
      pure Section
        { sectionId = ident
        , sectionName = name
        , sectionSport = sport
        , sectionCoachId = coach
        , sectionDescription = description
        , sectionActive = active
        }
    _ -> columnsMismatch "Section"

instance Entity ScheduleEntry where
  tableName _ = "section_schedule"
  columns _ = ["section_id", "weekday", "start_time", "end_time", "location"]
  entityId = unScheduleId . scheduleId
  toRow entry =
    [ toField (unSectionId (scheduleSectionId entry))
    , toField (weekdayToDB (scheduleWeekday entry))
    , toField (scheduleStart entry)
    , toField (scheduleEnd entry)
    , toField (scheduleLocation entry)
    ]
  fromRow row = case row of
    [idV, sectionV, weekdayV, startV, endV, locationV] -> do
      ident <- ScheduleId <$> decodeField "id" idV
      section <- SectionId <$> decodeField "section_id" sectionV
      weekday <- decodeEnumField "weekday" weekdayFromDB weekdayV
      start <- decodeField "start_time" startV
      end <- decodeField "end_time" endV
      location <- decodeField "location" locationV
      pure ScheduleEntry
        { scheduleId = ident
        , scheduleSectionId = section
        , scheduleWeekday = weekday
        , scheduleStart = start
        , scheduleEnd = end
        , scheduleLocation = location
        }
    _ -> columnsMismatch "ScheduleEntry"

instance Entity StudentSection where
  tableName _ = "student_sections"
  columns _ = ["student_id", "section_id", "joined_at", "active"]
  entityId = unStudentSectionId . membershipId
  toRow membership =
    [ toField (unStudentId (membershipStudentId membership))
    , toField (unSectionId (membershipSectionId membership))
    , toField (membershipJoinedAt membership)
    , toField (membershipActive membership)
    ]
  fromRow row = case row of
    [idV, studentV, sectionV, joinedV, activeV] -> do
      ident <- StudentSectionId <$> decodeField "id" idV
      student <- StudentId <$> decodeField "student_id" studentV
      section <- SectionId <$> decodeField "section_id" sectionV
      joined <- decodeField "joined_at" joinedV
      active <- decodeField "active" activeV
      pure StudentSection
        { membershipId = ident
        , membershipStudentId = student
        , membershipSectionId = section
        , membershipJoinedAt = joined
        , membershipActive = active
        }
    _ -> columnsMismatch "StudentSection"

instance Entity Competition where
  tableName _ = "competitions"
  columns _ =
    [ "title"
    , "sport"
    , "event_date"
    , "start_time"
    , "location"
    , "status"
    , "responsible_teacher_id"
    , "description"
    ]
  entityId = unCompetitionId . competitionId
  toRow competition =
    [ toField (competitionTitle competition)
    , toField (competitionSport competition)
    , toField (competitionDate competition)
    , toField (competitionStartTime competition)
    , toField (competitionLocation competition)
    , toField (competitionStatusToDB (competitionStatus competition))
    , toField (fmap unTeacherId (competitionResponsibleTeacherId competition))
    , toField (competitionDescription competition)
    ]
  fromRow row = case row of
    [ idV, titleV, sportV, dateV, startV, locationV, statusV, teacherV, descriptionV ] -> do
      ident <- CompetitionId <$> decodeField "id" idV
      title <- decodeField "title" titleV
      sport <- decodeField "sport" sportV
      date <- decodeField "event_date" dateV
      start <- decodeField "start_time" startV
      location <- decodeField "location" locationV
      status <- decodeEnumField "status" competitionStatusFromDB statusV
      teacher <- fmap TeacherId <$> decodeField "responsible_teacher_id" teacherV
      description <- decodeField "description" descriptionV
      pure Competition
        { competitionId = ident
        , competitionTitle = title
        , competitionSport = sport
        , competitionDate = date
        , competitionStartTime = start
        , competitionLocation = location
        , competitionStatus = status
        , competitionResponsibleTeacherId = teacher
        , competitionDescription = description
        }
    _ -> columnsMismatch "Competition"

instance Entity CompetitionParticipant where
  tableName _ = "competition_participants"
  columns _ = ["competition_id", "student_id", "place", "score"]
  entityId = unParticipantId . participantId
  toRow participant =
    [ toField (unCompetitionId (participantCompetitionId participant))
    , toField (unStudentId (participantStudentId participant))
    , toField (participantPlace participant)
    , toField (participantScore participant)
    ]
  fromRow row = case row of
    [idV, competitionV, studentV, placeV, scoreV] -> do
      ident <- ParticipantId <$> decodeField "id" idV
      competition <- CompetitionId <$> decodeField "competition_id" competitionV
      student <- StudentId <$> decodeField "student_id" studentV
      place <- decodeField "place" placeV
      score <- decodeField "score" scoreV
      pure CompetitionParticipant
        { participantId = ident
        , participantCompetitionId = competition
        , participantStudentId = student
        , participantPlace = place
        , participantScore = score
        }
    _ -> columnsMismatch "CompetitionParticipant"
