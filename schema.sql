-- ============================================================
--  MARITIME PORT MANAGEMENT SYSTEM — Full Schema + Sample Data
--  Compatible with MySQL 5.7+ / MariaDB
-- ============================================================

CREATE DATABASE IF NOT EXISTS maritime_port CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE maritime_port;

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- DROP ORDER (reverse dependency)
-- ============================================================
DROP TABLE IF EXISTS contains;
DROP TABLE IF EXISTS covers_cargo;
DROP TABLE IF EXISTS handles;
DROP TABLE IF EXISTS inspects;
DROP TABLE IF EXISTS scheduled_for;
DROP TABLE IF EXISTS assigned_to;
DROP TABLE IF EXISTS berths_at;
DROP TABLE IF EXISTS cargo_hazard_class;
DROP TABLE IF EXISTS cargo;
DROP TABLE IF EXISTS customs_inspection;
DROP TABLE IF EXISTS manifest;
DROP TABLE IF EXISTS schedule;
DROP TABLE IF EXISTS dock;
DROP TABLE IF EXISTS inspection_officer;
DROP TABLE IF EXISTS crane_operator;
DROP TABLE IF EXISTS dock_worker;
DROP TABLE IF EXISTS worker_certifications;
DROP TABLE IF EXISTS port_worker;
DROP TABLE IF EXISTS container_ship;
DROP TABLE IF EXISTS tanker;
DROP TABLE IF EXISTS bulk_vessel;
DROP TABLE IF EXISTS ship;
DROP TABLE IF EXISTS shipping_company;
DROP TABLE IF EXISTS company_contact_info;
DROP TABLE IF EXISTS cargo_owner;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS company_entity;
DROP TABLE IF EXISTS government;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- SHIPPING COMPANY
-- ============================================================
CREATE TABLE shipping_company (
    company_id   INT AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(120) NOT NULL,
    country      VARCHAR(80)  NOT NULL
);

CREATE TABLE company_contact_info (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    company_id INT         NOT NULL,
    contact    VARCHAR(200) NOT NULL,
    FOREIGN KEY (company_id) REFERENCES shipping_company(company_id) ON DELETE CASCADE
);

-- ============================================================
-- SHIP (disjoint total specialization)
-- ship_type must be one of: BULK, TANKER, CONTAINER
-- ============================================================
CREATE TABLE ship (
    ship_imo   VARCHAR(20)  PRIMARY KEY,
    ship_name  VARCHAR(120) NOT NULL,
    flag_state VARCHAR(80)  NOT NULL,
    tonnage    DECIMAL(12,2),                       -- derived/stored
    ship_type  ENUM('BULK','TANKER','CONTAINER') NOT NULL,
    company_id INT          NOT NULL,
    FOREIGN KEY (company_id) REFERENCES shipping_company(company_id)
);

CREATE TABLE bulk_vessel (
    ship_imo    VARCHAR(20) PRIMARY KEY,
    cargo_class VARCHAR(60),
    max_load    DECIMAL(12,2),
    FOREIGN KEY (ship_imo) REFERENCES ship(ship_imo) ON DELETE CASCADE
);

CREATE TABLE tanker (
    ship_imo       VARCHAR(20) PRIMARY KEY,
    liquid_type    VARCHAR(60),
    pressure_rating DECIMAL(8,2),
    FOREIGN KEY (ship_imo) REFERENCES ship(ship_imo) ON DELETE CASCADE
);

CREATE TABLE container_ship (
    ship_imo     VARCHAR(20) PRIMARY KEY,
    teu_capacity INT,
    reefer_slots INT,
    FOREIGN KEY (ship_imo) REFERENCES ship(ship_imo) ON DELETE CASCADE
);

-- ============================================================
-- DOCK
-- ============================================================
CREATE TABLE dock (
    dock_id      INT AUTO_INCREMENT PRIMARY KEY,
    dock_name    VARCHAR(80)  NOT NULL,
    dock_type    VARCHAR(60),
    max_capacity INT
);

-- ============================================================
-- SCHEDULE (weak entity — PK is composite: sched_no + dock_id)
-- ============================================================
CREATE TABLE schedule (
    sched_no       INT          NOT NULL,
    dock_id        INT          NOT NULL,
    arrival_time   DATETIME,
    departure_time DATETIME,
    status         VARCHAR(40),
    PRIMARY KEY (sched_no, dock_id),
    FOREIGN KEY (dock_id) REFERENCES dock(dock_id) ON DELETE CASCADE
);

-- ============================================================
-- PORT WORKER (overlapping partial specialization)
-- ============================================================
CREATE TABLE port_worker (
    worker_id   INT AUTO_INCREMENT PRIMARY KEY,
    worker_name VARCHAR(120) NOT NULL,
    shift_type  VARCHAR(40),
    supervisor_id INT NULL,
    FOREIGN KEY (supervisor_id) REFERENCES port_worker(worker_id)
);

CREATE TABLE worker_certifications (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    worker_id   INT         NOT NULL,
    certification VARCHAR(120) NOT NULL,
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id) ON DELETE CASCADE
);

-- Subtypes (overlapping — optional FK references)
CREATE TABLE dock_worker (
    worker_id     INT PRIMARY KEY,
    assigned_zone VARCHAR(80),
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id) ON DELETE CASCADE
);

CREATE TABLE crane_operator (
    worker_id     INT PRIMARY KEY,
    crane_licence VARCHAR(80),
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id) ON DELETE CASCADE
);

CREATE TABLE inspection_officer (
    worker_id INT PRIMARY KEY,
    badge_no  VARCHAR(40) UNIQUE NOT NULL,
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id) ON DELETE CASCADE
);

-- ============================================================
-- CARGO OWNER (Union / Category)
-- ============================================================
CREATE TABLE person (
    person_id   INT AUTO_INCREMENT PRIMARY KEY,
    person_name VARCHAR(120) NOT NULL
);

CREATE TABLE company_entity (
    company_reg  VARCHAR(40) PRIMARY KEY,
    company_name VARCHAR(120) NOT NULL
);

CREATE TABLE government (
    govt_code  VARCHAR(40) PRIMARY KEY,
    govt_name  VARCHAR(120) NOT NULL
);

CREATE TABLE cargo_owner (
    owner_id    INT AUTO_INCREMENT PRIMARY KEY,
    owner_type  ENUM('PERSON','COMPANY','GOVERNMENT') NOT NULL,
    person_id   INT        NULL,
    company_reg VARCHAR(40) NULL,
    govt_code   VARCHAR(40) NULL,
    FOREIGN KEY (person_id)   REFERENCES person(person_id),
    FOREIGN KEY (company_reg) REFERENCES company_entity(company_reg),
    FOREIGN KEY (govt_code)   REFERENCES government(govt_code),
    -- Only one FK set at a time
    CONSTRAINT chk_owner CHECK (
        (person_id IS NOT NULL AND company_reg IS NULL AND govt_code IS NULL) OR
        (person_id IS NULL AND company_reg IS NOT NULL AND govt_code IS NULL) OR
        (person_id IS NULL AND company_reg IS NULL AND govt_code IS NOT NULL)
    )
);

-- ============================================================
-- MANIFEST
-- ============================================================
CREATE TABLE manifest (
    manifest_no  INT AUTO_INCREMENT PRIMARY KEY,
    issue_date   DATE,
    total_items  INT DEFAULT 0,    -- derived; updated via trigger
    ship_imo     VARCHAR(20) NOT NULL,
    company_id   INT         NOT NULL,
    FOREIGN KEY (ship_imo)   REFERENCES ship(ship_imo),
    FOREIGN KEY (company_id) REFERENCES shipping_company(company_id)
);

-- ============================================================
-- CUSTOMS INSPECTION
-- ============================================================
CREATE TABLE customs_inspection (
    inspection_id  INT AUTO_INCREMENT PRIMARY KEY,
    insp_date      DATE,
    outcome        VARCHAR(80),
    inspector_name VARCHAR(120),
    worker_id      INT NULL,       -- conducting Inspection Officer
    FOREIGN KEY (worker_id) REFERENCES inspection_officer(worker_id)
);

-- ============================================================
-- CARGO
-- ============================================================
CREATE TABLE cargo (
    cargo_id      INT AUTO_INCREMENT PRIMARY KEY,
    cargo_type    VARCHAR(80),
    weight_kg     DECIMAL(12,2),
    owner_id      INT NOT NULL,
    manifest_no   INT NOT NULL,
    quantity      INT DEFAULT 1,
    inspection_id INT NULL,
    ship_imo      VARCHAR(20) NULL,
    FOREIGN KEY (owner_id)      REFERENCES cargo_owner(owner_id),
    FOREIGN KEY (manifest_no)   REFERENCES manifest(manifest_no),
    FOREIGN KEY (inspection_id) REFERENCES customs_inspection(inspection_id),
    FOREIGN KEY (ship_imo)      REFERENCES ship(ship_imo)
);

CREATE TABLE cargo_hazard_class (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    cargo_id     INT         NOT NULL,
    hazard_class VARCHAR(60) NOT NULL,
    FOREIGN KEY (cargo_id) REFERENCES cargo(cargo_id) ON DELETE CASCADE
);

-- ============================================================
-- JUNCTION TABLES
-- ============================================================
CREATE TABLE berths_at (
    dock_id        INT         NOT NULL,
    ship_imo       VARCHAR(20) NOT NULL,
    berth_date     DATE,
    berth_duration INT,           -- hours
    PRIMARY KEY (dock_id, ship_imo, berth_date),
    FOREIGN KEY (dock_id)  REFERENCES dock(dock_id),
    FOREIGN KEY (ship_imo) REFERENCES ship(ship_imo)
);

CREATE TABLE scheduled_for (
    sched_no INT         NOT NULL,
    dock_id  INT         NOT NULL,
    ship_imo VARCHAR(20) NOT NULL,
    PRIMARY KEY (sched_no, dock_id, ship_imo),
    FOREIGN KEY (sched_no, dock_id) REFERENCES schedule(sched_no, dock_id),
    FOREIGN KEY (ship_imo)          REFERENCES ship(ship_imo)
);

CREATE TABLE assigned_to (
    dock_id   INT NOT NULL,
    worker_id INT NOT NULL,
    PRIMARY KEY (dock_id, worker_id),
    FOREIGN KEY (dock_id)   REFERENCES dock(dock_id),
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id)
);

CREATE TABLE handles (
    worker_id    INT         NOT NULL,
    cargo_id     INT         NOT NULL,
    handling_date DATE,
    PRIMARY KEY (worker_id, cargo_id),
    FOREIGN KEY (worker_id) REFERENCES port_worker(worker_id),
    FOREIGN KEY (cargo_id)  REFERENCES cargo(cargo_id)
);

CREATE TABLE inspects (
    inspection_id INT NOT NULL,
    manifest_no   INT NOT NULL,
    PRIMARY KEY (inspection_id, manifest_no),
    FOREIGN KEY (inspection_id) REFERENCES customs_inspection(inspection_id),
    FOREIGN KEY (manifest_no)   REFERENCES manifest(manifest_no)
);

CREATE TABLE contains (
    cargo_id INT         NOT NULL,
    ship_imo VARCHAR(20) NOT NULL,
    PRIMARY KEY (cargo_id, ship_imo),
    FOREIGN KEY (cargo_id) REFERENCES cargo(cargo_id),
    FOREIGN KEY (ship_imo) REFERENCES ship(ship_imo)
);

-- ============================================================
-- TRIGGER: update total_items in manifest when cargo changes
-- ============================================================
DELIMITER $$

CREATE TRIGGER trg_cargo_insert
AFTER INSERT ON cargo
FOR EACH ROW
BEGIN
    UPDATE manifest
    SET total_items = (SELECT COUNT(*) FROM cargo WHERE manifest_no = NEW.manifest_no)
    WHERE manifest_no = NEW.manifest_no;
END$$

CREATE TRIGGER trg_cargo_delete
AFTER DELETE ON cargo
FOR EACH ROW
BEGIN
    UPDATE manifest
    SET total_items = (SELECT COUNT(*) FROM cargo WHERE manifest_no = OLD.manifest_no)
    WHERE manifest_no = OLD.manifest_no;
END$$

DELIMITER ;

-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- Shipping Companies
INSERT INTO shipping_company (company_name, country) VALUES
('Maersk Line',      'Denmark'),
('MSC Shipping',     'Switzerland'),
('COSCO Pacific',    'China'),
('Evergreen Marine', 'Taiwan');

INSERT INTO company_contact_info (company_id, contact) VALUES
(1, 'info@maersk.com'),
(1, '+45-3363-3363'),
(2, 'contact@msc.com'),
(3, 'info@cosco.com'),
(4, 'pr@evergreen.com');

-- Ships
INSERT INTO ship (ship_imo, ship_name, flag_state, tonnage, ship_type, company_id) VALUES
('IMO9321483', 'Emma Maersk',    'Denmark',   170794, 'CONTAINER', 1),
('IMO9723456', 'MSC Oscar',      'Panama',    197362, 'CONTAINER', 2),
('IMO9612345', 'COSCO Bulk 01',  'China',      85000, 'BULK',      3),
('IMO9456789', 'Pacific Tanker', 'Liberia',    62000, 'TANKER',    4),
('IMO9888001', 'Green Horizon',  'Taiwan',    120000, 'CONTAINER', 4);

INSERT INTO container_ship (ship_imo, teu_capacity, reefer_slots) VALUES
('IMO9321483', 15552, 1000),
('IMO9723456', 19224, 1200),
('IMO9888001', 14000, 900);

INSERT INTO bulk_vessel (ship_imo, cargo_class, max_load) VALUES
('IMO9612345', 'Grain/Coal', 80000.00);

INSERT INTO tanker (ship_imo, liquid_type, pressure_rating) VALUES
('IMO9456789', 'Crude Oil', 12.50);

-- Docks
INSERT INTO dock (dock_name, dock_type, max_capacity) VALUES
('Dock Alpha',   'Container', 5),
('Dock Bravo',   'Bulk',      3),
('Dock Charlie', 'Tanker',    2),
('Dock Delta',   'General',   4);

-- Schedules
INSERT INTO schedule (sched_no, dock_id, arrival_time, departure_time, status) VALUES
(1, 1, '2025-07-01 06:00:00', '2025-07-03 18:00:00', 'Completed'),
(2, 1, '2025-07-05 08:00:00', '2025-07-07 20:00:00', 'Scheduled'),
(1, 2, '2025-07-02 10:00:00', '2025-07-04 16:00:00', 'Completed'),
(1, 3, '2025-07-06 07:00:00', '2025-07-07 19:00:00', 'In Progress');

-- Port Workers
INSERT INTO port_worker (worker_name, shift_type, supervisor_id) VALUES
('Ahmed Khan',    'Morning',   NULL),
('Sara Malik',    'Night',     1),
('James Cooper',  'Morning',   1),
('Lina Chen',     'Evening',   1),
('Tariq Mahmood', 'Night',     2);

INSERT INTO worker_certifications (worker_id, certification) VALUES
(1, 'Forklift Operation'),
(1, 'Safety Level 3'),
(2, 'Crane Operation'),
(3, 'Hazmat Handling'),
(4, 'Port Security'),
(5, 'First Aid');

-- Subtypes (overlapping)
INSERT INTO dock_worker    (worker_id, assigned_zone)  VALUES (1, 'Zone A'), (3, 'Zone B');
INSERT INTO crane_operator (worker_id, crane_licence)  VALUES (2, 'CR-4521'), (3, 'CR-7890');
INSERT INTO inspection_officer (worker_id, badge_no)   VALUES (4, 'IO-001'), (5, 'IO-002');

-- Cargo Owners
INSERT INTO person (person_name) VALUES ('Ali Hassan'), ('Emma Schulz');
INSERT INTO company_entity (company_reg, company_name) VALUES ('REG-UK-001', 'BritishGoods Ltd'), ('REG-CN-002', 'Shanghai Exports');
INSERT INTO government (govt_code, govt_name) VALUES ('GOV-PK', 'Pakistan Ministry of Commerce'), ('GOV-DE', 'German Federal Trade Office');

INSERT INTO cargo_owner (owner_type, person_id, company_reg, govt_code) VALUES
('PERSON',     1,    NULL,         NULL),
('PERSON',     2,    NULL,         NULL),
('COMPANY',    NULL, 'REG-UK-001', NULL),
('COMPANY',    NULL, 'REG-CN-002', NULL),
('GOVERNMENT', NULL, NULL,         'GOV-PK'),
('GOVERNMENT', NULL, NULL,         'GOV-DE');

-- Manifests
INSERT INTO manifest (issue_date, ship_imo, company_id) VALUES
('2025-07-01', 'IMO9321483', 1),
('2025-07-02', 'IMO9723456', 2),
('2025-07-03', 'IMO9612345', 3),
('2025-07-05', 'IMO9888001', 4);

-- Customs Inspections
INSERT INTO customs_inspection (insp_date, outcome, inspector_name, worker_id) VALUES
('2025-07-01', 'Cleared',  'Officer Lina Chen',     4),
('2025-07-03', 'Held',     'Officer Tariq Mahmood', 5),
('2025-07-05', 'Cleared',  'Officer Lina Chen',     4);

-- Cargo
INSERT INTO cargo (cargo_type, weight_kg, owner_id, manifest_no, quantity, inspection_id) VALUES
('Electronics',      5000.00, 1, 1, 200, 1),
('Textiles',         3200.00, 2, 1,  80, 1),
('Industrial Parts', 9800.00, 3, 2, 150, 2),
('Food Grains',     15000.00, 5, 3, 500, 3),
('Chemicals',        7500.00, 4, 4,  60, 3),
('Machinery',       20000.00, 6, 4,  30, NULL);

INSERT INTO cargo_hazard_class (cargo_id, hazard_class) VALUES
(5, 'Class 3 - Flammable Liquid'),
(5, 'Class 8 - Corrosive');

-- Berths
INSERT INTO berths_at (dock_id, ship_imo, berth_date, berth_duration) VALUES
(1, 'IMO9321483', '2025-07-01', 48),
(1, 'IMO9723456', '2025-07-05', 36),
(2, 'IMO9612345', '2025-07-02', 72),
(3, 'IMO9456789', '2025-07-06', 24);

-- Scheduled For
INSERT INTO scheduled_for VALUES
(1,1,'IMO9321483'),
(2,1,'IMO9723456'),
(1,2,'IMO9612345'),
(1,3,'IMO9456789');

-- Assigned To
INSERT INTO assigned_to VALUES
(1,1),(1,2),(2,3),(3,4),(4,5);

-- Handles
INSERT INTO handles VALUES
(1,1,'2025-07-01'),(2,2,'2025-07-01'),(3,3,'2025-07-03'),(4,4,'2025-07-05');

-- Inspects (junction)
INSERT INTO inspects VALUES (1,1),(1,2),(2,3),(3,4);

-- Contains
INSERT INTO contains VALUES
(1,'IMO9321483'),(2,'IMO9321483'),
(3,'IMO9723456'),
(4,'IMO9612345'),
(5,'IMO9888001'),(6,'IMO9888001');
