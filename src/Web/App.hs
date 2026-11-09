{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Web.App
  ( Env (..)
  , runApp
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Pool (Pool)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Time (Day, utctDay)
import Data.Time.Clock (getCurrentTime)
import Database.MySQL.Base (MySQLConn)
import Network.HTTP.Types.Status (status400, status404, status409, status500)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Network.Wai.Middleware.Static (addBase, staticPolicy)
import Text.Blaze.Html (Html)
import qualified Text.Blaze.Html.Renderer.Text as HR
import Text.Read (readMaybe)
import qualified Web.Scotty as S

import Config (Config (..))
import DB.Entity (Entity)
import DB.Instances ()
import qualified DB.Queries as Q
import qualified DB.Repository as R
import Domain.Model
import Domain.Validation (AppError (..), FieldError (..))
import qualified Web.Forms as F
import qualified Web.Views as V

data Env = Env
  { envPool   :: Pool MySQLConn
  , envConfig :: Config
  }

runApp :: Config -> Pool MySQLConn -> IO ()
runApp config pool = do
  putStrLn $ "Sport at the faculty: http://localhost:" <> show (configWebPort config)
  S.scotty (configWebPort config) (app (Env pool config))

app :: Env -> S.ScottyM ()
app env = do
  S.middleware logStdoutDev
  S.middleware $ staticPolicy (addBase "static")

  S.get "/" $ do
    today <- todayAction
    runAction (Q.dashboardStats (envPool env) today) $ \stats ->
      sendHtml (V.pageDashboard stats)

  -- Faculties -------------------------------------------------------------
  S.get "/faculties" $ do
    flash <- okMessage
    runAction (Q.listFaculties (envPool env)) $ \faculties ->
      sendHtml (V.pageFaculties faculties flash)

  S.get "/faculties/new" $
    sendHtml (V.facultyFormPage "Новий факультет" "/faculties" Map.empty [])

  S.post "/faculties" $ do
    form <- formFromRequest
    case F.parseFacultyInput form of
      Left errors ->
        sendHtml (V.facultyFormPage "Новий факультет" "/faculties" form errors)
      Right input ->
        runAction (R.insert (envPool env) (Faculty (FacultyId 0) (inputFacultyName input) (inputFacultyDean input))) $ \_ ->
          redirectTo "/faculties?ok=1"

  S.get "/faculties/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @Faculty env ident) $ \faculty ->
      sendHtml (V.facultyFormPage "Редагувати факультет" ("/faculties/" <> showText ident) (V.facultyFormValues (Just faculty)) [])

  S.post "/faculties/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseFacultyInput form of
      Left errors ->
        sendHtml (V.facultyFormPage "Редагувати факультет" ("/faculties/" <> showText ident) form errors)
      Right input ->
        runAction (R.update (envPool env) (Faculty (FacultyId ident) (inputFacultyName input) (inputFacultyDean input))) $ \_ ->
          redirectTo "/faculties?ok=1"

  -- Students --------------------------------------------------------------
  S.get "/students" $ do
    flash <- okMessage
    runAction (Q.listStudents (envPool env)) $ \students ->
      sendHtml (V.pageStudents students flash)

  S.get "/students/new" $
    runAction (Q.facultyOptions (envPool env)) $ \faculties ->
      sendHtml (V.studentFormPage "Новий студент" "/students" (V.studentFormValues Nothing) [] faculties)

  S.post "/students" $ do
    form <- formFromRequest
    case F.parseStudentInput form of
      Left errors ->
        runAction (Q.facultyOptions (envPool env)) $ \faculties ->
          sendHtml (V.studentFormPage "Новий студент" "/students" form errors faculties)
      Right input ->
        runAction (R.insert (envPool env) (studentFromInput 0 input)) $ \_ ->
          redirectTo "/students?ok=1"

  S.get "/students/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @Student env ident) $ \student ->
      runAction (Q.facultyOptions (envPool env)) $ \faculties ->
        sendHtml (V.studentFormPage "Редагувати студента" ("/students/" <> showText ident) (V.studentFormValues (Just student)) [] faculties)

  S.post "/students/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseStudentInput form of
      Left errors ->
        runAction (Q.facultyOptions (envPool env)) $ \faculties ->
          sendHtml (V.studentFormPage "Редагувати студента" ("/students/" <> showText ident) form errors faculties)
      Right input ->
        runAction (R.update (envPool env) (studentFromInput ident input)) $ \_ ->
          redirectTo "/students?ok=1"

  -- Teachers --------------------------------------------------------------
  S.get "/teachers" $ do
    flash <- okMessage
    runAction (Q.listTeachers (envPool env)) $ \teachers ->
      sendHtml (V.pageTeachers teachers flash)

  S.get "/teachers/new" $
    runAction (Q.facultyOptions (envPool env)) $ \faculties ->
      sendHtml (V.teacherFormPage "Новий викладач" "/teachers" (V.teacherFormValues Nothing) [] faculties)

  S.post "/teachers" $ do
    form <- formFromRequest
    case F.parseTeacherInput form of
      Left errors ->
        runAction (Q.facultyOptions (envPool env)) $ \faculties ->
          sendHtml (V.teacherFormPage "Новий викладач" "/teachers" form errors faculties)
      Right input ->
        runAction (R.insert (envPool env) (teacherFromInput 0 input)) $ \_ ->
          redirectTo "/teachers?ok=1"

  S.get "/teachers/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @Teacher env ident) $ \teacher ->
      runAction (Q.facultyOptions (envPool env)) $ \faculties ->
        sendHtml (V.teacherFormPage "Редагувати викладача" ("/teachers/" <> showText ident) (V.teacherFormValues (Just teacher)) [] faculties)

  S.post "/teachers/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseTeacherInput form of
      Left errors ->
        runAction (Q.facultyOptions (envPool env)) $ \faculties ->
          sendHtml (V.teacherFormPage "Редагувати викладача" ("/teachers/" <> showText ident) form errors faculties)
      Right input ->
        runAction (R.update (envPool env) (teacherFromInput ident input)) $ \_ ->
          redirectTo "/teachers?ok=1"

  -- Sections --------------------------------------------------------------
  S.get "/sections" $ do
    flash <- okMessage
    runAction (Q.listSections (envPool env)) $ \sections ->
      sendHtml (V.pageSections sections flash)

  S.get "/sections/new" $
    runAction (Q.teacherOptions (envPool env)) $ \teachers ->
      sendHtml (V.sectionFormPage "Нова секція" "/sections" (V.sectionFormValues Nothing) [] teachers)

  S.post "/sections" $ do
    form <- formFromRequest
    case F.parseSectionInput form of
      Left errors ->
        runAction (Q.teacherOptions (envPool env)) $ \teachers ->
          sendHtml (V.sectionFormPage "Нова секція" "/sections" form errors teachers)
      Right input ->
        runAction (R.insert (envPool env) (sectionFromInput 0 input)) $ \_ ->
          redirectTo "/sections?ok=1"

  S.get "/sections/:id" $ withParamId $ \ident -> do
    runAction (Q.getSectionDetails (envPool env) (SectionId ident)) $ \mDetails ->
      case mDetails of
        Nothing -> renderError (NotFoundError "Секцію не знайдено")
        Just details -> do
          today <- todayAction
          runAction (Q.studentOptions (envPool env)) $ \students -> do
            flash <- okMessage
            sendHtml (V.pageSectionDetails today details students flash)

  S.get "/sections/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @Section env ident) $ \section ->
      runAction (Q.teacherOptions (envPool env)) $ \teachers ->
        sendHtml (V.sectionFormPage "Редагувати секцію" ("/sections/" <> showText ident) (V.sectionFormValues (Just section)) [] teachers)

  S.post "/sections/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseSectionInput form of
      Left errors ->
        runAction (Q.teacherOptions (envPool env)) $ \teachers ->
          sendHtml (V.sectionFormPage "Редагувати секцію" ("/sections/" <> showText ident) form errors teachers)
      Right input ->
        runAction (R.update (envPool env) (sectionFromInput ident input)) $ \_ ->
          redirectTo "/sections?ok=1"

  S.post "/sections/:id/schedule" $ withParamId $ \sectionIdent -> do
    form <- formFromRequest
    case F.parseScheduleInput form of
      Left errors ->
        sendHtml (V.scheduleEditPage "Додати заняття" ("/sections/" <> showText sectionIdent <> "/schedule") form errors)
      Right input ->
        runAction (R.insert (envPool env) (scheduleFromInput 0 (SectionId sectionIdent) input)) $ \_ ->
          redirectTo ("/sections/" <> showText sectionIdent <> "?ok=1")

  S.get "/schedule/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @ScheduleEntry env ident) $ \entry ->
      sendHtml (V.scheduleEditPage "Редагувати заняття" ("/schedule/" <> showText ident) (V.scheduleFormValues (Just entry) (scheduleSectionId entry)) [])

  S.post "/schedule/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseScheduleInput form of
      Left errors ->
        sendHtml (V.scheduleEditPage "Редагувати заняття" ("/schedule/" <> showText ident) form errors)
      Right input ->
        runAction (R.update (envPool env) (scheduleFromInput ident (inputScheduleSectionId input) input)) $ \_ ->
          redirectTo ("/sections/" <> showText (unSectionId (inputScheduleSectionId input)) <> "?ok=1")

  S.post "/schedule/:id/delete" $ withParamId $ \ident ->
    runAction (loadRequired @ScheduleEntry env ident) $ \entry -> do
      runAction (R.delete @ScheduleEntry (envPool env) ident) $ \_ ->
        redirectTo ("/sections/" <> showText (unSectionId (scheduleSectionId entry)) <> "?ok=1")

  S.post "/sections/:id/students" $ withParamId $ \sectionIdent -> do
    form <- formFromRequest
    case F.parseStudentSectionInput form of
      Left errors ->
        runAction (Q.studentOptions (envPool env)) $ \students ->
          sendHtml (V.membershipEditPage "Записати студента" ("/sections/" <> showText sectionIdent <> "/students") form errors students)
      Right input ->
        runAction (R.insert (envPool env) (membershipFromInput 0 (SectionId sectionIdent) input)) $ \_ ->
          redirectTo ("/sections/" <> showText sectionIdent <> "?ok=1")

  S.get "/memberships/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @StudentSection env ident) $ \membership ->
      runAction (Q.studentOptions (envPool env)) $ \students ->
        sendHtml (V.membershipEditPage "Редагувати участь" ("/memberships/" <> showText ident) (V.membershipFormValues (Just membership) (membershipJoinedAt membership) (membershipSectionId membership)) [] students)

  S.post "/memberships/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseStudentSectionInput form of
      Left errors ->
        runAction (Q.studentOptions (envPool env)) $ \students ->
          sendHtml (V.membershipEditPage "Редагувати участь" ("/memberships/" <> showText ident) form errors students)
      Right input ->
        runAction (R.update (envPool env) (membershipFromInput ident (inputMembershipSectionId input) input)) $ \_ ->
          redirectTo ("/sections/" <> showText (unSectionId (inputMembershipSectionId input)) <> "?ok=1")

  S.post "/memberships/:id/delete" $ withParamId $ \ident ->
    runAction (loadRequired @StudentSection env ident) $ \membership -> do
      runAction (R.delete @StudentSection (envPool env) ident) $ \_ ->
        redirectTo ("/sections/" <> showText (unSectionId (membershipSectionId membership)) <> "?ok=1")

  -- Competitions ----------------------------------------------------------
  S.get "/competitions" $ do
    flash <- okMessage
    runAction (Q.listCompetitions (envPool env)) $ \competitions ->
      sendHtml (V.pageCompetitions competitions flash)

  S.get "/competitions/new" $ do
    today <- todayAction
    runAction (Q.teacherOptions (envPool env)) $ \teachers ->
      sendHtml (V.competitionFormPage "Нове змагання" "/competitions" (V.competitionFormValues Nothing today) [] teachers)

  S.post "/competitions" $ do
    form <- formFromRequest
    case F.parseCompetitionInput form of
      Left errors ->
        runAction (Q.teacherOptions (envPool env)) $ \teachers ->
          sendHtml (V.competitionFormPage "Нове змагання" "/competitions" form errors teachers)
      Right input ->
        runAction (R.insert (envPool env) (competitionFromInput 0 input)) $ \_ ->
          redirectTo "/competitions?ok=1"

  S.get "/competitions/:id" $ withParamId $ \ident -> do
    runAction (Q.getCompetitionDetails (envPool env) (CompetitionId ident)) $ \mDetails ->
      case mDetails of
        Nothing -> renderError (NotFoundError "Змагання не знайдено")
        Just details ->
          runAction (Q.studentOptions (envPool env)) $ \students -> do
            flash <- okMessage
            sendHtml (V.pageCompetitionDetails details students flash)

  S.get "/competitions/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @Competition env ident) $ \competition ->
      runAction (Q.teacherOptions (envPool env)) $ \teachers ->
        sendHtml (V.competitionFormPage "Редагувати змагання" ("/competitions/" <> showText ident) (V.competitionFormValues (Just competition) (competitionDate competition)) [] teachers)

  S.post "/competitions/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseCompetitionInput form of
      Left errors ->
        runAction (Q.teacherOptions (envPool env)) $ \teachers ->
          sendHtml (V.competitionFormPage "Редагувати змагання" ("/competitions/" <> showText ident) form errors teachers)
      Right input ->
        runAction (R.update (envPool env) (competitionFromInput ident input)) $ \_ ->
          redirectTo "/competitions?ok=1"

  S.post "/competitions/:id/participants" $ withParamId $ \competitionIdent -> do
    form <- formFromRequest
    case F.parseParticipantInput form of
      Left errors ->
        runAction (Q.studentOptions (envPool env)) $ \students ->
          sendHtml (V.participantEditPage "Додати учасника" ("/competitions/" <> showText competitionIdent <> "/participants") form errors students)
      Right input ->
        runAction (R.insert (envPool env) (participantFromInput 0 (CompetitionId competitionIdent) input)) $ \_ ->
          redirectTo ("/competitions/" <> showText competitionIdent <> "?ok=1")

  S.get "/participants/:id/edit" $ withParamId $ \ident ->
    runAction (loadRequired @CompetitionParticipant env ident) $ \participant ->
      runAction (Q.studentOptions (envPool env)) $ \students ->
        sendHtml (V.participantEditPage "Редагувати учасника" ("/participants/" <> showText ident) (V.participantFormValues (Just participant) (participantCompetitionId participant)) [] students)

  S.post "/participants/:id" $ withParamId $ \ident -> do
    form <- formFromRequest
    case F.parseParticipantInput form of
      Left errors ->
        runAction (Q.studentOptions (envPool env)) $ \students ->
          sendHtml (V.participantEditPage "Редагувати учасника" ("/participants/" <> showText ident) form errors students)
      Right input ->
        runAction (R.update (envPool env) (participantFromInput ident (inputParticipantCompetitionId input) input)) $ \_ ->
          redirectTo ("/competitions/" <> showText (unCompetitionId (inputParticipantCompetitionId input)) <> "?ok=1")

  S.post "/participants/:id/delete" $ withParamId $ \ident ->
    runAction (loadRequired @CompetitionParticipant env ident) $ \participant -> do
      runAction (R.delete @CompetitionParticipant (envPool env) ident) $ \_ ->
        redirectTo ("/competitions/" <> showText (unCompetitionId (participantCompetitionId participant)) <> "?ok=1")

  S.get "/health" $
    runAction (R.pingDB (envPool env)) $ \_ -> S.text "ok"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

runAction :: IO (Either AppError a) -> (a -> S.ActionM ()) -> S.ActionM ()
runAction action onSuccess = do
  result <- liftIO action
  case result of
    Left err -> renderError err
    Right value -> onSuccess value

renderError :: AppError -> S.ActionM ()
renderError err = case err of
  ValidationErrors errors -> do
    S.status status400
    sendHtml $ V.pageError "Помилка валідації" (T.intercalate "; " [fieldName e <> ": " <> fieldMessage e | e <- errors])
  NotFoundError message -> do
    S.status status404
    sendHtml $ V.pageNotFound message
  ConflictError message -> do
    S.status status409
    sendHtml $ V.pageError "Конфлікт даних" message
  DatabaseError message -> do
    S.status status500
    sendHtml $ V.pageError "Помилка бази даних" ("Перевірте з'єднання з MySQL. Деталі: " <> message)
  UnexpectedError message -> do
    S.status status500
    sendHtml $ V.pageError "Непередбачена помилка" message

loadRequired :: forall a. Entity a => Env -> Int64 -> IO (Either AppError a)
loadRequired env ident = do
  result <- R.findById @a (envPool env) ident
  pure $ result >>= maybe (Left (NotFoundError "Запис не знайдено")) Right

sendHtml :: Html -> S.ActionM ()
sendHtml = S.html . HR.renderHtml

redirectTo :: Text -> S.ActionM a
redirectTo = S.redirect303 . TL.fromStrict

withParamId :: (Int64 -> S.ActionM ()) -> S.ActionM ()
withParamId action = do
  raw :: Text <- S.pathParam "id"
  case readMaybe (T.unpack raw) of
    Just ident -> action ident
    Nothing -> renderError (NotFoundError "Некоректний ідентифікатор")

formFromRequest :: S.ActionM F.FormMap
formFromRequest = F.formMapFromParams <$> S.formParams

okMessage :: S.ActionM (Maybe Text)
okMessage = do
  params <- S.queryParams
  pure $ if lookup "ok" params == Just "1" then Just "Збережено" else Nothing

todayAction :: S.ActionM Day
todayAction = utctDay <$> liftIO getCurrentTime

showText :: Show a => a -> Text
showText = T.pack . show

studentFromInput :: Int64 -> StudentInput -> Student
studentFromInput ident input =
  Student
    { studentId = StudentId ident
    , studentFacultyId = inputStudentFacultyId input
    , studentFullName = inputStudentFullName input
    , studentGroup = inputStudentGroup input
    , studentBirthDate = inputStudentBirthDate input
    , studentEmail = inputStudentEmail input
    , studentPhone = inputStudentPhone input
    , studentActive = inputStudentActive input
    }

teacherFromInput :: Int64 -> TeacherInput -> Teacher
teacherFromInput ident input =
  Teacher
    { teacherId = TeacherId ident
    , teacherFacultyId = inputTeacherFacultyId input
    , teacherFullName = inputTeacherFullName input
    , teacherDepartment = inputTeacherDepartment input
    , teacherPosition = inputTeacherPosition input
    , teacherEmail = inputTeacherEmail input
    , teacherPhone = inputTeacherPhone input
    , teacherActive = inputTeacherActive input
    }

sectionFromInput :: Int64 -> SectionInput -> Section
sectionFromInput ident input =
  Section
    { sectionId = SectionId ident
    , sectionName = inputSectionName input
    , sectionSport = inputSectionSport input
    , sectionCoachId = inputSectionCoachId input
    , sectionDescription = inputSectionDescription input
    , sectionActive = inputSectionActive input
    }

scheduleFromInput :: Int64 -> SectionId -> ScheduleInput -> ScheduleEntry
scheduleFromInput ident sectionId input =
  ScheduleEntry
    { scheduleId = ScheduleId ident
    , scheduleSectionId = sectionId
    , scheduleWeekday = inputScheduleWeekday input
    , scheduleStart = inputScheduleStart input
    , scheduleEnd = inputScheduleEnd input
    , scheduleLocation = inputScheduleLocation input
    }

membershipFromInput :: Int64 -> SectionId -> StudentSectionInput -> StudentSection
membershipFromInput ident sectionId input =
  StudentSection
    { membershipId = StudentSectionId ident
    , membershipStudentId = inputMembershipStudentId input
    , membershipSectionId = sectionId
    , membershipJoinedAt = inputMembershipJoinedAt input
    , membershipActive = inputMembershipActive input
    }

competitionFromInput :: Int64 -> CompetitionInput -> Competition
competitionFromInput ident input =
  Competition
    { competitionId = CompetitionId ident
    , competitionTitle = inputCompetitionTitle input
    , competitionSport = inputCompetitionSport input
    , competitionDate = inputCompetitionDate input
    , competitionStartTime = inputCompetitionStartTime input
    , competitionLocation = inputCompetitionLocation input
    , competitionStatus = inputCompetitionStatus input
    , competitionResponsibleTeacherId = inputCompetitionResponsibleTeacherId input
    , competitionDescription = inputCompetitionDescription input
    }

participantFromInput :: Int64 -> CompetitionId -> ParticipantInput -> CompetitionParticipant
participantFromInput ident competitionId input =
  CompetitionParticipant
    { participantId = ParticipantId ident
    , participantCompetitionId = competitionId
    , participantStudentId = inputParticipantStudentId input
    , participantPlace = inputParticipantPlace input
    , participantScore = inputParticipantScore input
    }
