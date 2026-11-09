{-# LANGUAGE OverloadedStrings #-}

module Web.Views where

import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, TimeOfDay, defaultTimeLocale, formatTime)
import Text.Blaze (AttributeValue, customAttribute, toValue)
import Text.Blaze.Html5 (Html, (!), toHtml)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

import DB.Queries
import Domain.Model
import Domain.Validation (FieldError (..))
import Web.Forms (FormMap, formValue)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

txt :: Text -> Html
txt = toHtml . T.unpack

val :: Text -> AttributeValue
val = toValue . T.unpack

tshow :: Show a => a -> Text
tshow = T.pack . show

formatDayDisplay :: Day -> Text
formatDayDisplay = T.pack . formatTime defaultTimeLocale "%d.%m.%Y"

formatDayValue :: Day -> Text
formatDayValue = T.pack . formatTime defaultTimeLocale "%Y-%m-%d"

formatTimeDisplay :: TimeOfDay -> Text
formatTimeDisplay = T.pack . formatTime defaultTimeLocale "%H:%M"

formatTimeValue :: TimeOfDay -> Text
formatTimeValue = T.pack . formatTime defaultTimeLocale "%H:%M"

formatMaybeTime :: Maybe TimeOfDay -> Text
formatMaybeTime = maybe "—" formatTimeDisplay

formatMaybeText :: Maybe Text -> Text
formatMaybeText = fromMaybe "—"

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

layout :: Text -> Html -> Html
layout pageTitle content =
  H.docType <> htmlPage
  where
    htmlPage =
      H.html ! A.lang "uk" ! customAttribute "data-theme" "light" $ do
        H.head $ do
          H.meta ! A.charset "utf-8"
          H.meta ! A.name "color-scheme" ! A.content "light"
          H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
          H.title $ txt (pageTitle <> " | Спорт на факультеті")
          H.link ! A.rel "icon" ! A.type_ "image/svg+xml" ! A.href "/favicon.svg"
          H.link ! A.rel "stylesheet" ! A.href "/pico.min.css"
          H.link ! A.rel "stylesheet" ! A.href "/style.css"
        H.body $ do
          navBar
          H.main ! A.class_ "container" $ do
            H.h1 $ txt pageTitle
            content

navBar :: Html
navBar =
  H.nav ! A.class_ "container" $
    H.ul ! A.class_ "nav-links" $ do
      H.li $ H.a ! A.href "/" $ txt "Головна"
      H.li $ H.a ! A.href "/faculties" $ txt "Факультети"
      H.li $ H.a ! A.href "/students" $ txt "Студенти"
      H.li $ H.a ! A.href "/teachers" $ txt "Викладачі"
      H.li $ H.a ! A.href "/sections" $ txt "Секції"
      H.li $ H.a ! A.href "/competitions" $ txt "Змагання"

flashSuccess :: Maybe Text -> Html
flashSuccess Nothing = mempty
flashSuccess (Just message) =
  H.div ! A.class_ "flash success" $ txt message

errorList :: [FieldError] -> Html
errorList [] = mempty
errorList errors =
  H.div ! A.class_ "flash error" $
    H.ul $ mapM_ (\err -> H.li $ txt (fieldName err <> ": " <> fieldMessage err)) errors

fieldErrorFor :: Text -> [FieldError] -> Html
fieldErrorFor name errors =
  case [err | err <- errors, fieldName err == name] of
    [] -> mempty
    (err:_) -> H.small ! A.class_ "field-error" $ txt (fieldMessage err)

formField :: Text -> Html -> Html
formField label input =
  H.label $ do
    txt label
    input

textInput :: Text -> Text -> Html
textInput name value =
  H.input ! A.type_ "text" ! A.name (val name) ! A.value (val value)

emailInput :: Text -> Text -> Html
emailInput name value =
  H.input ! A.type_ "email" ! A.name (val name) ! A.value (val value)

dateInput :: Text -> Text -> Html
dateInput name value =
  H.input ! A.type_ "date" ! A.name (val name) ! A.value (val value)

timeInput :: Text -> Text -> Html
timeInput name value =
  H.input ! A.type_ "time" ! A.name (val name) ! A.value (val value)

numberInput :: Text -> Text -> Text -> Html
numberInput name value step =
  H.input ! A.type_ "number" ! A.name (val name) ! A.value (val value) ! A.step (val step)

textareaInput :: Text -> Text -> Html
textareaInput name value =
  H.textarea ! A.name (val name) $ txt value

hiddenInput :: Text -> Text -> Html
hiddenInput name value =
  H.input ! A.type_ "hidden" ! A.name (val name) ! A.value (val value)

checkboxInput :: Text -> Bool -> Html
checkboxInput name checked =
  if checked
    then H.input ! A.type_ "checkbox" ! A.name (val name) ! A.value "on" ! A.checked "checked"
    else H.input ! A.type_ "checkbox" ! A.name (val name) ! A.value "on"

selectInput :: Text -> [(Int64, Text)] -> Text -> Html
selectInput name options selected =
  H.select ! A.name (val name) $
    mapM_ (optionHtml selected . (\(ident, label) -> (tshow ident, label))) options

selectInputWithEmpty :: Text -> Text -> [(Int64, Text)] -> Text -> Html
selectInputWithEmpty name emptyLabel options selected =
  H.select ! A.name (val name) $ do
    optionHtml selected ("", emptyLabel)
    mapM_ (optionHtml selected . (\(ident, label) -> (tshow ident, label))) options

optionHtml :: Text -> (Text, Text) -> Html
optionHtml selected (value, label) =
  let base = H.option ! A.value (val value)
  in if value == selected
       then base ! A.selected "selected" $ txt label
       else base $ txt label

selectTextInput :: Text -> [(Text, Text)] -> Text -> Html
selectTextInput name options selected =
  H.select ! A.name (val name) $
    mapM_ (optionHtml selected) options

submitButton :: Text -> Html
submitButton label =
  H.button ! A.type_ "submit" $ txt label

deleteButton :: Text -> Html
deleteButton action =
  H.form ! A.method "post" ! A.action (val action) ! A.class_ "inline-form" $
    H.button ! A.type_ "submit" ! A.class_ "secondary outline" ! A.onclick "return confirm('Видалити цей запис?')" $
      txt "Видалити"

dataTable :: [Html] -> [[Html]] -> Html
dataTable headers rows =
  H.div ! A.class_ "table-wrap" $
    H.table $ do
      H.thead $ H.tr $ mapM_ H.th headers
      H.tbody $
        if null rows
          then H.tr $ H.td ! A.colspan (val (tshow (length headers))) $ txt "Немає даних"
          else mapM_ (\cells -> H.tr $ mapM_ H.td cells) rows

statusBadge :: Bool -> Html
statusBadge True = H.span ! A.class_ "badge success" $ txt "Активний"
statusBadge False = H.span ! A.class_ "badge muted" $ txt "Неактивний"

-- ---------------------------------------------------------------------------
-- Dashboard
-- ---------------------------------------------------------------------------

pageDashboard :: DashboardStats -> Html
pageDashboard stats =
  layout "Головна" $ do
    H.div ! A.class_ "stats-grid" $ do
      statCard "Студенти" (statStudentsCount stats) "/students"
      statCard "Викладачі" (statTeachersCount stats) "/teachers"
      statCard "Секції" (statSectionsCount stats) "/sections"
      statCard "Змагання" (statCompetitionsCount stats) "/competitions"
    H.h2 $ txt "Найближчі змагання"
    if null (statUpcoming stats)
      then H.p $ txt "Найближчих змагань поки немає."
      else
        dataTable
          [txt "Назва", txt "Вид спорту", txt "Дата", txt "Час", txt "Місце", txt "Статус"]
          [ [ H.a ! A.href (val ("/competitions/" <> tshow (unCompetitionId (competitionId competition)))) $
                txt (competitionTitle competition)
            , txt (competitionSport competition)
            , txt (formatDayDisplay (competitionDate competition))
            , txt (formatMaybeTime (competitionStartTime competition))
            , txt (competitionLocation competition)
            , txt (competitionStatusLabel (competitionStatus competition))
            ]
          | competition <- statUpcoming stats
          ]

statCard :: Text -> Int64 -> Text -> Html
statCard label count link =
  H.article ! A.class_ "stat-card" $ do
    H.span ! A.class_ "stat-number" $ txt (tshow count)
    H.span ! A.class_ "stat-label" $ txt label
    H.a ! A.href (val link) $ txt "Переглянути"

-- ---------------------------------------------------------------------------
-- Faculties
-- ---------------------------------------------------------------------------

pageFaculties :: [Faculty] -> Maybe Text -> Html
pageFaculties faculties flash =
  layout "Факультети" $ do
    flashSuccess flash
    H.p $ H.a ! A.href "/faculties/new" ! A.role "button" $ txt "Додати факультет"
    dataTable
      [txt "Назва", txt "Декан", txt "Дії"]
      [ [ txt (facultyName faculty)
        , txt (formatMaybeText (facultyDean faculty))
        , H.a ! A.href (val ("/faculties/" <> tshow (unFacultyId (facultyId faculty)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
        ]
      | faculty <- faculties
      ]

facultyFormPage :: Text -> Text -> FormMap -> [FieldError] -> Html
facultyFormPage title action form errors =
  layout title $ do
    errorList errors
    H.form ! A.method "post" ! A.action (val action) $ do
      formField "Назва" $ textInput "name" (formValue "name" form)
      fieldErrorFor "name" errors
      formField "Декан" $ textInput "dean" (formValue "dean" form)
      submitButton "Зберегти"

facultyFormValues :: Maybe Faculty -> FormMap
facultyFormValues Nothing = Map.empty
facultyFormValues (Just faculty) =
  Map.fromList
    [ ("name", facultyName faculty)
    , ("dean", fromMaybe "" (facultyDean faculty))
    ]

-- ---------------------------------------------------------------------------
-- Students
-- ---------------------------------------------------------------------------

pageStudents :: [StudentListItem] -> Maybe Text -> Html
pageStudents students flash =
  layout "Студенти" $ do
    flashSuccess flash
    H.p $ H.a ! A.href "/students/new" ! A.role "button" $ txt "Додати студента"
    dataTable
      [txt "ПІБ", txt "Група", txt "Факультет", txt "Email", txt "Телефон", txt "Статус", txt "Дії"]
      [ [ txt (studentFullName student)
        , txt (studentGroup student)
        , txt facultyName
        , txt (formatMaybeText (studentEmail student))
        , txt (formatMaybeText (studentPhone student))
        , statusBadge (studentActive student)
        , H.a ! A.href (val ("/students/" <> tshow (unStudentId (studentId student)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
        ]
      | (student, facultyName) <- students
      ]

studentFormPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
studentFormPage title action form errors faculties =
  layout title $ do
    errorList errors
    H.form ! A.method "post" ! A.action (val action) $ do
      formField "Факультет" $ selectInput "faculty_id" faculties (formValue "faculty_id" form)
      fieldErrorFor "faculty_id" errors
      formField "ПІБ" $ textInput "full_name" (formValue "full_name" form)
      fieldErrorFor "full_name" errors
      formField "Група" $ textInput "group_code" (formValue "group_code" form)
      fieldErrorFor "group_code" errors
      formField "Дата народження" $ dateInput "birth_date" (formValue "birth_date" form)
      fieldErrorFor "birth_date" errors
      formField "Email" $ emailInput "email" (formValue "email" form)
      fieldErrorFor "email" errors
      formField "Телефон" $ textInput "phone" (formValue "phone" form)
      formField "Активний" $ checkboxInput "active" (formValue "active" form /= "")
      submitButton "Зберегти"

studentFormValues :: Maybe Student -> FormMap
studentFormValues Nothing = Map.fromList [("active", "on")]
studentFormValues (Just student) =
  Map.fromList
    [ ("faculty_id", tshow (unFacultyId (studentFacultyId student)))
    , ("full_name", studentFullName student)
    , ("group_code", studentGroup student)
    , ("birth_date", maybe "" formatDayValue (studentBirthDate student))
    , ("email", fromMaybe "" (studentEmail student))
    , ("phone", fromMaybe "" (studentPhone student))
    , ("active", if studentActive student then "on" else "")
    ]

-- ---------------------------------------------------------------------------
-- Teachers
-- ---------------------------------------------------------------------------

pageTeachers :: [TeacherListItem] -> Maybe Text -> Html
pageTeachers teachers flash =
  layout "Викладачі" $ do
    flashSuccess flash
    H.p $ H.a ! A.href "/teachers/new" ! A.role "button" $ txt "Додати викладача"
    dataTable
      [txt "ПІБ", txt "Факультет", txt "Кафедра", txt "Посада", txt "Email", txt "Статус", txt "Дії"]
      [ [ txt (teacherFullName teacher)
        , txt facultyName
        , txt (teacherDepartment teacher)
        , txt (teacherPosition teacher)
        , txt (formatMaybeText (teacherEmail teacher))
        , statusBadge (teacherActive teacher)
        , H.a ! A.href (val ("/teachers/" <> tshow (unTeacherId (teacherId teacher)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
        ]
      | (teacher, facultyName) <- teachers
      ]

teacherFormPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
teacherFormPage title action form errors faculties =
  layout title $ do
    errorList errors
    H.form ! A.method "post" ! A.action (val action) $ do
      formField "Факультет" $ selectInput "faculty_id" faculties (formValue "faculty_id" form)
      fieldErrorFor "faculty_id" errors
      formField "ПІБ" $ textInput "full_name" (formValue "full_name" form)
      fieldErrorFor "full_name" errors
      formField "Кафедра" $ textInput "department" (formValue "department" form)
      fieldErrorFor "department" errors
      formField "Посада" $ textInput "position" (formValue "position" form)
      fieldErrorFor "position" errors
      formField "Email" $ emailInput "email" (formValue "email" form)
      fieldErrorFor "email" errors
      formField "Телефон" $ textInput "phone" (formValue "phone" form)
      formField "Активний" $ checkboxInput "active" (formValue "active" form /= "")
      submitButton "Зберегти"

teacherFormValues :: Maybe Teacher -> FormMap
teacherFormValues Nothing = Map.fromList [("active", "on")]
teacherFormValues (Just teacher) =
  Map.fromList
    [ ("faculty_id", tshow (unFacultyId (teacherFacultyId teacher)))
    , ("full_name", teacherFullName teacher)
    , ("department", teacherDepartment teacher)
    , ("position", teacherPosition teacher)
    , ("email", fromMaybe "" (teacherEmail teacher))
    , ("phone", fromMaybe "" (teacherPhone teacher))
    , ("active", if teacherActive teacher then "on" else "")
    ]

-- ---------------------------------------------------------------------------
-- Sections
-- ---------------------------------------------------------------------------

pageSections :: [SectionListItem] -> Maybe Text -> Html
pageSections sections flash =
  layout "Секції" $ do
    flashSuccess flash
    H.p $ H.a ! A.href "/sections/new" ! A.role "button" $ txt "Додати секцію"
    dataTable
      [txt "Назва", txt "Вид спорту", txt "Тренер", txt "Занять", txt "Учасників", txt "Статус", txt "Дії"]
      [ [ H.a ! A.href (val ("/sections/" <> tshow (unSectionId (sectionId section)))) $ txt (sectionName section)
        , txt (sectionSport section)
        , txt (formatMaybeText coachName)
        , txt (tshow scheduleCount)
        , txt (tshow memberCount)
        , statusBadge (sectionActive section)
        , H.div ! A.class_ "actions" $ do
            H.a ! A.href (val ("/sections/" <> tshow (unSectionId (sectionId section)))) ! A.role "button" ! A.class_ "outline" $ txt "Деталі"
            H.a ! A.href (val ("/sections/" <> tshow (unSectionId (sectionId section)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
        ]
      | (section, coachName, scheduleCount, memberCount) <- sections
      ]

sectionFormPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
sectionFormPage title action form errors teachers =
  layout title $ do
    errorList errors
    H.form ! A.method "post" ! A.action (val action) $ do
      formField "Назва" $ textInput "name" (formValue "name" form)
      fieldErrorFor "name" errors
      formField "Вид спорту" $ textInput "sport" (formValue "sport" form)
      fieldErrorFor "sport" errors
      formField "Тренер" $ selectInputWithEmpty "coach_id" "Без тренера" teachers (formValue "coach_id" form)
      formField "Опис" $ textareaInput "description" (formValue "description" form)
      formField "Активна" $ checkboxInput "active" (formValue "active" form /= "")
      submitButton "Зберегти"

sectionFormValues :: Maybe Section -> FormMap
sectionFormValues Nothing = Map.fromList [("active", "on")]
sectionFormValues (Just section) =
  Map.fromList
    [ ("name", sectionName section)
    , ("sport", sectionSport section)
    , ("coach_id", maybe "" (tshow . unTeacherId) (sectionCoachId section))
    , ("description", fromMaybe "" (sectionDescription section))
    , ("active", if sectionActive section then "on" else "")
    ]

pageSectionDetails :: Day -> SectionDetails -> [(Int64, Text)] -> Maybe Text -> Html
pageSectionDetails today details students flash =
  layout (sectionName (detailSection details)) $ do
    flashSuccess flash
    H.article ! A.class_ "detail-card" $ do
      H.p $ do txt "Вид спорту: " >> H.strong (txt (sectionSport (detailSection details)))
      H.p $ do txt "Тренер: " >> H.strong (txt (maybe "—" teacherFullName (detailCoach details)))
      H.p $ do txt "Опис: " >> txt (formatMaybeText (sectionDescription (detailSection details)))
      H.p $ do txt "Статус: " >> statusBadge (sectionActive (detailSection details))
    H.h2 $ txt "Розклад"
    dataTable
      [txt "День", txt "Початок", txt "Кінець", txt "Місце", txt "Дії"]
      [ [ txt (weekdayLabel (scheduleWeekday entry))
        , txt (formatTimeDisplay (scheduleStart entry))
        , txt (formatTimeDisplay (scheduleEnd entry))
        , txt (scheduleLocation entry)
        , H.div ! A.class_ "actions" $ do
            H.a ! A.href (val ("/schedule/" <> tshow (unScheduleId (scheduleId entry)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
            deleteButton ("/schedule/" <> tshow (unScheduleId (scheduleId entry)) <> "/delete")
        ]
      | entry <- detailSchedule details
      ]
    H.details $ do
      H.summary $ txt "Додати заняття"
      scheduleForm ("/sections/" <> tshow (unSectionId (sectionId (detailSection details))) <> "/schedule")
        (scheduleFormValues Nothing (sectionId (detailSection details))) [] "Додати заняття"

    H.h2 $ txt "Студенти"
    dataTable
      [txt "ПІБ", txt "Дата запису", txt "Статус", txt "Дії"]
      [ [ txt studentName
        , txt (formatDayDisplay (membershipJoinedAt membership))
        , statusBadge (membershipActive membership)
        , H.div ! A.class_ "actions" $ do
            H.a ! A.href (val ("/memberships/" <> tshow (unStudentSectionId (membershipId membership)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
            deleteButton ("/memberships/" <> tshow (unStudentSectionId (membershipId membership)) <> "/delete")
        ]
      | (membership, studentName) <- detailStudents details
      ]
    H.details $ do
      H.summary $ txt "Записати студента"
      membershipForm ("/sections/" <> tshow (unSectionId (sectionId (detailSection details))) <> "/students")
        (membershipFormValues Nothing today (sectionId (detailSection details))) [] students

scheduleForm :: Text -> FormMap -> [FieldError] -> Text -> Html
scheduleForm action form errors buttonLabel =
  H.form ! A.method "post" ! A.action (val action) $ do
    errorList errors
    hiddenInput "section_id" (formValue "section_id" form)
    formField "День" $ selectTextInput "weekday" weekdayOptions (formValue "weekday" form)
    fieldErrorFor "weekday" errors
    formField "Початок" $ timeInput "start_time" (formValue "start_time" form)
    fieldErrorFor "start_time" errors
    formField "Кінець" $ timeInput "end_time" (formValue "end_time" form)
    fieldErrorFor "end_time" errors
    formField "Місце" $ textInput "location" (formValue "location" form)
    fieldErrorFor "location" errors
    submitButton buttonLabel

scheduleEditPage :: Text -> Text -> FormMap -> [FieldError] -> Html
scheduleEditPage title action form errors =
  layout title $ scheduleForm action form errors "Зберегти"

scheduleFormValues :: Maybe ScheduleEntry -> SectionId -> FormMap
scheduleFormValues Nothing sectionId =
  Map.fromList
    [ ("section_id", tshow (unSectionId sectionId))
    , ("weekday", weekdayToDB Monday)
    , ("start_time", "17:00")
    , ("end_time", "18:30")
    , ("location", "Спортзал")
    ]
scheduleFormValues (Just entry) _ =
  Map.fromList
    [ ("section_id", tshow (unSectionId (scheduleSectionId entry)))
    , ("weekday", weekdayToDB (scheduleWeekday entry))
    , ("start_time", formatTimeValue (scheduleStart entry))
    , ("end_time", formatTimeValue (scheduleEnd entry))
    , ("location", scheduleLocation entry)
    ]

membershipForm :: Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
membershipForm action form errors students =
  H.form ! A.method "post" ! A.action (val action) $ do
    errorList errors
    hiddenInput "section_id" (formValue "section_id" form)
    formField "Студент" $ selectInput "student_id" students (formValue "student_id" form)
    fieldErrorFor "student_id" errors
    formField "Дата запису" $ dateInput "joined_at" (formValue "joined_at" form)
    fieldErrorFor "joined_at" errors
    formField "Активна участь" $ checkboxInput "active" (formValue "active" form /= "")
    submitButton "Зберегти"

membershipEditPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
membershipEditPage title action form errors students =
  layout title $ membershipForm action form errors students

membershipFormValues :: Maybe StudentSection -> Day -> SectionId -> FormMap
membershipFormValues Nothing today sectionId =
  Map.fromList
    [ ("section_id", tshow (unSectionId sectionId))
    , ("joined_at", formatDayValue today)
    , ("active", "on")
    ]
membershipFormValues (Just membership) _ _ =
  Map.fromList
    [ ("section_id", tshow (unSectionId (membershipSectionId membership)))
    , ("student_id", tshow (unStudentId (membershipStudentId membership)))
    , ("joined_at", formatDayValue (membershipJoinedAt membership))
    , ("active", if membershipActive membership then "on" else "")
    ]

-- ---------------------------------------------------------------------------
-- Competitions
-- ---------------------------------------------------------------------------

pageCompetitions :: [CompetitionListItem] -> Maybe Text -> Html
pageCompetitions competitions flash =
  layout "Змагання" $ do
    flashSuccess flash
    H.p $ H.a ! A.href "/competitions/new" ! A.role "button" $ txt "Додати змагання"
    dataTable
      [txt "Назва", txt "Вид спорту", txt "Дата", txt "Час", txt "Місце", txt "Статус", txt "Відповідальний", txt "Учасників", txt "Дії"]
      [ [ H.a ! A.href (val ("/competitions/" <> tshow (unCompetitionId (competitionId competition)))) $ txt (competitionTitle competition)
        , txt (competitionSport competition)
        , txt (formatDayDisplay (competitionDate competition))
        , txt (formatMaybeTime (competitionStartTime competition))
        , txt (competitionLocation competition)
        , txt (competitionStatusLabel (competitionStatus competition))
        , txt (formatMaybeText teacherName)
        , txt (tshow participantCount)
        , H.div ! A.class_ "actions" $ do
            H.a ! A.href (val ("/competitions/" <> tshow (unCompetitionId (competitionId competition)))) ! A.role "button" ! A.class_ "outline" $ txt "Деталі"
            H.a ! A.href (val ("/competitions/" <> tshow (unCompetitionId (competitionId competition)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
        ]
      | (competition, teacherName, participantCount) <- competitions
      ]

competitionFormPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
competitionFormPage title action form errors teachers =
  layout title $ do
    errorList errors
    H.form ! A.method "post" ! A.action (val action) $ do
      formField "Назва" $ textInput "title" (formValue "title" form)
      fieldErrorFor "title" errors
      formField "Вид спорту" $ textInput "sport" (formValue "sport" form)
      fieldErrorFor "sport" errors
      formField "Дата" $ dateInput "event_date" (formValue "event_date" form)
      fieldErrorFor "event_date" errors
      formField "Час" $ timeInput "start_time" (formValue "start_time" form)
      fieldErrorFor "start_time" errors
      formField "Місце" $ textInput "location" (formValue "location" form)
      fieldErrorFor "location" errors
      formField "Статус" $ selectTextInput "status" competitionStatusOptions (formValue "status" form)
      fieldErrorFor "status" errors
      formField "Відповідальний викладач" $ selectInputWithEmpty "responsible_teacher_id" "Без відповідального" teachers (formValue "responsible_teacher_id" form)
      formField "Опис" $ textareaInput "description" (formValue "description" form)
      submitButton "Зберегти"

competitionFormValues :: Maybe Competition -> Day -> FormMap
competitionFormValues Nothing today =
  Map.fromList
    [ ("event_date", formatDayValue today)
    , ("status", competitionStatusToDB Planned)
    ]
competitionFormValues (Just competition) _ =
  Map.fromList
    [ ("title", competitionTitle competition)
    , ("sport", competitionSport competition)
    , ("event_date", formatDayValue (competitionDate competition))
    , ("start_time", maybe "" formatTimeValue (competitionStartTime competition))
    , ("location", competitionLocation competition)
    , ("status", competitionStatusToDB (competitionStatus competition))
    , ("responsible_teacher_id", maybe "" (tshow . unTeacherId) (competitionResponsibleTeacherId competition))
    , ("description", fromMaybe "" (competitionDescription competition))
    ]

pageCompetitionDetails :: CompetitionDetails -> [(Int64, Text)] -> Maybe Text -> Html
pageCompetitionDetails details students flash =
  layout (competitionTitle (detailCompetition details)) $ do
    flashSuccess flash
    H.article ! A.class_ "detail-card" $ do
      H.p $ do txt "Вид спорту: " >> H.strong (txt (competitionSport (detailCompetition details)))
      H.p $ do txt "Дата: " >> H.strong (txt (formatDayDisplay (competitionDate (detailCompetition details))))
      H.p $ do txt "Час: " >> H.strong (txt (formatMaybeTime (competitionStartTime (detailCompetition details))))
      H.p $ do txt "Місце: " >> H.strong (txt (competitionLocation (detailCompetition details)))
      H.p $ do txt "Статус: " >> H.strong (txt (competitionStatusLabel (competitionStatus (detailCompetition details))))
      H.p $ do txt "Відповідальний: " >> H.strong (txt (maybe "—" teacherFullName (detailTeacher details)))
      H.p $ do txt "Опис: " >> txt (formatMaybeText (competitionDescription (detailCompetition details)))
    H.h2 $ txt "Учасники"
    dataTable
      [txt "ПІБ", txt "Місце", txt "Результат", txt "Дії"]
      [ [ txt studentName
        , txt (maybe "—" tshow (participantPlace participant))
        , txt (maybe "—" (T.pack . show) (participantScore participant))
        , H.div ! A.class_ "actions" $ do
            H.a ! A.href (val ("/participants/" <> tshow (unParticipantId (participantId participant)) <> "/edit")) ! A.role "button" ! A.class_ "outline" $ txt "Редагувати"
            deleteButton ("/participants/" <> tshow (unParticipantId (participantId participant)) <> "/delete")
        ]
      | (participant, studentName) <- detailParticipants details
      ]
    H.details $ do
      H.summary $ txt "Додати учасника"
      participantForm ("/competitions/" <> tshow (unCompetitionId (competitionId (detailCompetition details))) <> "/participants")
        (participantFormValues Nothing (competitionId (detailCompetition details))) [] students

participantForm :: Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
participantForm action form errors students =
  H.form ! A.method "post" ! A.action (val action) $ do
    errorList errors
    hiddenInput "competition_id" (formValue "competition_id" form)
    formField "Студент" $ selectInput "student_id" students (formValue "student_id" form)
    fieldErrorFor "student_id" errors
    formField "Місце" $ numberInput "place" (formValue "place" form) "1"
    fieldErrorFor "place" errors
    formField "Результат" $ numberInput "score" (formValue "score" form) "0.1"
    fieldErrorFor "score" errors
    submitButton "Зберегти"

participantEditPage :: Text -> Text -> FormMap -> [FieldError] -> [(Int64, Text)] -> Html
participantEditPage title action form errors students =
  layout title $ participantForm action form errors students

participantFormValues :: Maybe CompetitionParticipant -> CompetitionId -> FormMap
participantFormValues Nothing competitionId =
  Map.fromList [("competition_id", tshow (unCompetitionId competitionId))]
participantFormValues (Just participant) _ =
  Map.fromList
    [ ("competition_id", tshow (unCompetitionId (participantCompetitionId participant)))
    , ("student_id", tshow (unStudentId (participantStudentId participant)))
    , ("place", maybe "" tshow (participantPlace participant))
    , ("score", maybe "" (T.pack . show) (participantScore participant))
    ]

-- ---------------------------------------------------------------------------
-- Errors
-- ---------------------------------------------------------------------------

pageError :: Text -> Text -> Html
pageError title message =
  layout title $ do
    H.div ! A.class_ "flash error" $ txt message
    H.p $ H.a ! A.href "/" ! A.role "button" $ txt "На головну"

pageNotFound :: Text -> Html
pageNotFound message = pageError "Не знайдено" message
