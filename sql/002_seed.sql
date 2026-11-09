USE sport_faculty;

SET NAMES utf8mb4;

INSERT INTO faculties (id, name, dean) VALUES
  (1, 'Факультет інформаційних технологій', 'Іван Петренко'),
  (2, 'Факультет фізичного виховання', 'Олена Коваль');

INSERT INTO teachers (id, faculty_id, full_name, department, position, email, phone, active) VALUES
  (1, 2, 'Олександр Шевченко', 'Кафедра фізичного виховання', 'Тренер', 'shevchenko@sport.edu.ua', '+380501110101', TRUE),
  (2, 2, 'Марія Бондаренко', 'Кафедра спортивних ігор', 'Старший викладач', 'bondarenko@sport.edu.ua', '+380501110102', TRUE),
  (3, 1, 'Андрій Мельник', 'Кафедра інформаційних систем', 'Доцент', 'melnyk@it.edu.ua', '+380501110103', TRUE);

INSERT INTO students (id, faculty_id, full_name, group_code, birth_date, email, phone, active) VALUES
  (1, 1, 'Анна Коваленко', 'ІТ-21', '2004-03-12', 'anna.kovalenko@student.edu.ua', '+380671110101', TRUE),
  (2, 1, 'Богдан Сидоренко', 'ІТ-22', '2003-09-25', 'bohdan.sydorenko@student.edu.ua', '+380671110102', TRUE),
  (3, 2, 'Вікторія Гончар', 'ФВ-21', '2004-01-18', 'viktoria.honchar@student.edu.ua', '+380671110103', TRUE),
  (4, 1, 'Дмитро Мороз', 'ІТ-21', '2003-11-07', 'dmytro.moroz@student.edu.ua', '+380671110104', TRUE),
  (5, 2, 'Софія Литвин', 'ФВ-22', '2005-05-30', 'sofia.lytvyn@student.edu.ua', '+380671110105', TRUE),
  (6, 1, 'Максим Руденко', 'ІТ-23', '2004-08-14', 'maksym.rudenko@student.edu.ua', '+380671110106', TRUE);

INSERT INTO sections (id, name, sport, coach_id, description, active) VALUES
  (1, 'Футбол', 'Футбол', 1, 'Секція футболу для студентів усіх факультетів.', TRUE),
  (2, 'Баскетбол', 'Баскетбол', 2, 'Тренування з баскетболу та підготовка до університетських змагань.', TRUE),
  (3, 'Волейбол', 'Волейбол', 2, 'Волейбольна секція, тренування двічі на тиждень.', TRUE),
  (4, 'Настільний теніс', 'Настільний теніс', 3, 'Секція настільного тенісу для початківців і досвідчених гравців.', TRUE);

INSERT INTO section_schedule (id, section_id, weekday, start_time, end_time, location) VALUES
  (1, 1, 'Mon', '17:00:00', '18:30:00', 'Спортивний майданчик'),
  (2, 1, 'Wed', '17:00:00', '18:30:00', 'Спортивний майданчик'),
  (3, 2, 'Tue', '18:00:00', '19:30:00', 'Спортивний зал №1'),
  (4, 3, 'Thu', '16:00:00', '17:30:00', 'Спортивний зал №2'),
  (5, 4, 'Fri', '15:00:00', '16:00:00', 'Кімната настільного тенісу');

INSERT INTO student_sections (id, student_id, section_id, joined_at, active) VALUES
  (1, 1, 1, '2025-09-15', TRUE),
  (2, 4, 1, '2025-09-16', TRUE),
  (3, 2, 2, '2025-09-17', TRUE),
  (4, 5, 2, '2025-09-17', TRUE),
  (5, 3, 3, '2025-09-18', TRUE),
  (6, 6, 4, '2025-09-19', TRUE);

INSERT INTO competitions (id, title, sport, event_date, start_time, location, status, responsible_teacher_id, description) VALUES
  (1, 'Університетська футбольна ліга', 'Футбол', '2026-11-20', '15:00:00', 'Спортивний комплекс', 'planned', 1, 'Матчі між факультетськими командами.'),
  (2, 'Баскетбольний турнір', 'Баскетбол', '2026-12-05', '10:00:00', 'Спортивний зал №1', 'planned', 2, 'Турнір серед студентських команд.'),
  (3, 'Турнір з настільного тенісу', 'Настільний теніс', '2026-10-15', '14:00:00', 'Кімната настільного тенісу', 'completed', 3, 'Особистий залік серед студентів.');

INSERT INTO competition_participants (id, competition_id, student_id, place, score) VALUES
  (1, 1, 1, NULL, NULL),
  (2, 1, 4, NULL, NULL),
  (3, 2, 2, NULL, NULL),
  (4, 2, 5, NULL, NULL),
  (5, 3, 6, 1, 3.0);
