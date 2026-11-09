CREATE DATABASE IF NOT EXISTS sport_faculty
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sport_faculty;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS faculties (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  dean VARCHAR(150) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_faculties_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS students (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  faculty_id BIGINT       NOT NULL,
  full_name  VARCHAR(150) NOT NULL,
  group_code VARCHAR(30)  NOT NULL,
  birth_date DATE         NULL,
  email      VARCHAR(150) NULL,
  phone      VARCHAR(40)  NULL,
  active     BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_students_email (email),
  KEY idx_students_faculty (faculty_id),
  CONSTRAINT fk_students_faculty
    FOREIGN KEY (faculty_id) REFERENCES faculties (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS teachers (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  faculty_id BIGINT       NOT NULL,
  full_name  VARCHAR(150) NOT NULL,
  department VARCHAR(120) NOT NULL,
  position   VARCHAR(120) NOT NULL,
  email      VARCHAR(150) NULL,
  phone      VARCHAR(40)  NULL,
  active     BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_teachers_email (email),
  KEY idx_teachers_faculty (faculty_id),
  CONSTRAINT fk_teachers_faculty
    FOREIGN KEY (faculty_id) REFERENCES faculties (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sections (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(120) NOT NULL,
  sport       VARCHAR(80)  NOT NULL,
  coach_id    BIGINT       NULL,
  description TEXT         NULL,
  active      BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sections_name (name),
  KEY idx_sections_coach (coach_id),
  CONSTRAINT fk_sections_coach
    FOREIGN KEY (coach_id) REFERENCES teachers (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS section_schedule (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  section_id BIGINT       NOT NULL,
  weekday    ENUM('Mon','Tue','Wed','Thu','Fri','Sat','Sun') NOT NULL,
  start_time TIME         NOT NULL,
  end_time   TIME         NOT NULL,
  location   VARCHAR(120) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_schedule_slot (section_id, weekday, start_time),
  KEY idx_schedule_section (section_id),
  CONSTRAINT chk_schedule_time CHECK (end_time > start_time),
  CONSTRAINT fk_schedule_section
    FOREIGN KEY (section_id) REFERENCES sections (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS student_sections (
  id         BIGINT  NOT NULL AUTO_INCREMENT,
  student_id BIGINT  NOT NULL,
  section_id BIGINT  NOT NULL,
  joined_at  DATE    NOT NULL,
  active     BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_student_section (student_id, section_id),
  KEY idx_student_sections_section (section_id),
  CONSTRAINT fk_student_sections_student
    FOREIGN KEY (student_id) REFERENCES students (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_student_sections_section
    FOREIGN KEY (section_id) REFERENCES sections (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS competitions (
  id                     BIGINT       NOT NULL AUTO_INCREMENT,
  title                  VARCHAR(150) NOT NULL,
  sport                  VARCHAR(80)  NOT NULL,
  event_date             DATE         NOT NULL,
  start_time             TIME         NULL,
  location               VARCHAR(120) NOT NULL,
  status                 ENUM('planned','in_progress','completed','cancelled') NOT NULL DEFAULT 'planned',
  responsible_teacher_id BIGINT       NULL,
  description            TEXT         NULL,
  PRIMARY KEY (id),
  KEY idx_competitions_date (event_date),
  KEY idx_competitions_teacher (responsible_teacher_id),
  CONSTRAINT fk_competitions_teacher
    FOREIGN KEY (responsible_teacher_id) REFERENCES teachers (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS competition_participants (
  id             BIGINT NOT NULL AUTO_INCREMENT,
  competition_id BIGINT NOT NULL,
  student_id     BIGINT NOT NULL,
  place          INT    NULL,
  score          DOUBLE NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_competition_participant (competition_id, student_id),
  KEY idx_participants_student (student_id),
  CONSTRAINT chk_participant_place CHECK (place IS NULL OR place > 0),
  CONSTRAINT chk_participant_score CHECK (score IS NULL OR score >= 0),
  CONSTRAINT fk_participants_competition
    FOREIGN KEY (competition_id) REFERENCES competitions (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_participants_student
    FOREIGN KEY (student_id) REFERENCES students (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
