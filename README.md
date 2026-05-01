# Maritime Port Management System — Phase 2
## Setup Guide (Read First!)

================================================================
WHAT YOU GET
================================================================
maritime-port/
├── schema.sql          ← Run this in MySQL to create all tables + data
├── server.js           ← Node.js backend (API)
├── package.json        ← Node dependencies
├── public/
│   └── index.html      ← The entire web frontend (open in browser)
└── README.md           ← This file

================================================================
STEP 1 — Install Node.js (if not already installed)
================================================================
Download from: https://nodejs.org  (choose "LTS" version)
After install, open a terminal/command prompt and check:
    node --version
    npm --version
Both should print a version number.

================================================================
STEP 2 — Set up the MySQL database
================================================================
1. Open MySQL Workbench (or phpMyAdmin, or the MySQL command line)
2. Open the file: schema.sql
3. Run/Execute the entire file
   - In Workbench: File → Open SQL Script → select schema.sql → click ⚡ Execute
   - In command line: mysql -u root -p < schema.sql
4. You should now have a database called "maritime_port" with all tables and sample data.

================================================================
STEP 3 — Configure your MySQL password in server.js
================================================================
Open server.js in any text editor (Notepad, VS Code, etc.)
Find this section near the top:

    const pool = mysql.createPool({
        host:     'localhost',
        user:     'root',
        password: '',      ← PUT YOUR MYSQL PASSWORD HERE (between the quotes)
        database: 'maritime_port',
        ...
    });

Save the file.

If your MySQL username is NOT "root", change that too.

================================================================
STEP 4 — Install Node.js packages
================================================================
Open a terminal/command prompt IN the maritime-port folder:
    cd path/to/maritime-port

Then run:
    npm install

This installs Express, MySQL2, and CORS. Takes about 30 seconds.

================================================================
STEP 5 — Start the server
================================================================
In the same terminal, run:
    node server.js

You should see:
    Maritime Port System running → http://localhost:3000

Leave this terminal open while using the app.

================================================================
STEP 6 — Open the web app
================================================================
Open your browser and go to:
    http://localhost:3000

That's it! The full app should load.

================================================================
CRUD OPERATIONS SUMMARY (for your evaluator)
================================================================

SHIPS (Fleet Registry):
  CREATE → Click "+ Add Ship" → fill form → Save Ship
  READ   → Ships table loads automatically; use search box to filter
  UPDATE → Click "✏ Edit" on any ship row → change fields → Save Ship
  DELETE → Click "✕ Del" on any ship row → confirm

COMPANIES, DOCKS, WORKERS, CARGO, MANIFESTS, INSPECTIONS, SCHEDULES:
  All follow the exact same CREATE / READ / UPDATE / DELETE pattern.
  Use the left sidebar to navigate between sections.

================================================================
EERD COMPLIANCE NOTES (for your evaluator)
================================================================

✅ Disjoint Total Specialization (SHIP):
   ship_type column enforces ENUM('BULK','TANKER','CONTAINER')
   Subtype tables: bulk_vessel, tanker, container_ship
   Each ship MUST have exactly one subtype row.

✅ Overlapping Partial Specialization (PORT WORKER):
   dock_worker, crane_operator, inspection_officer are OPTIONAL
   A worker can be in multiple subtype tables simultaneously.
   The UI shows checkboxes for each role.

✅ Weak Entity (SCHEDULE):
   Primary key is composite: (sched_no, dock_id)
   dock_id is a FK to DOCK (identifying relationship HAS SCHEDULE)

✅ Multivalued Attributes:
   worker_certifications  → for PORT WORKER certifications
   company_contact_info   → for SHIPPING COMPANY contact_info
   cargo_hazard_class     → for CARGO hazard_class

✅ Union/Category (CARGO OWNER):
   cargo_owner table has surrogate PK (owner_id)
   Nullable FKs to person, company_entity, government
   CHECK constraint ensures exactly one FK is set

✅ Derived Attributes:
   tonnage stored directly in ship table
   total_items in manifest updated by AFTER INSERT/DELETE triggers on cargo

✅ All 15 relationships implemented:
   1.  OWNS          → company_id FK in ship
   2.  BERTHS_AT     → junction table berths_at (with berth_date, berth_duration)
   3.  HAS SCHEDULE  → dock_id FK in schedule (identifying)
   4.  SCHEDULED_FOR → junction table scheduled_for
   5.  ASSIGNED_TO   → junction table assigned_to
   6.  SUPERVISES    → self-referencing supervisor_id in port_worker
   7.  CARRIED_ON    → ship_imo FK in manifest (total participation: NOT NULL)
   8.  ISSUES        → company_id FK in manifest
   9.  OWNED_BY      → owner_id FK in cargo
   10. LISTS         → manifest_no FK + quantity in cargo
   11. HANDLES       → junction table handles (with handling_date)
   12. INSPECTS      → junction table inspects (total participation on customs_inspection)
   13. COVERS        → inspection_id FK in cargo
   14. CONDUCTS      → worker_id FK in customs_inspection
   15. CONTAINS      → junction table contains

================================================================
TROUBLESHOOTING
================================================================

"Cannot connect to database" (red dot in header):
  → Make sure MySQL is running
  → Check your password in server.js
  → Make sure you ran schema.sql successfully

"npm install" fails:
  → Make sure Node.js is installed
  → Make sure you are in the maritime-port folder

Port 3000 already in use:
  → Change PORT=3000 to PORT=3001 in server.js
  → Then go to http://localhost:3001

Foreign key error when deleting:
  → Delete child records first (e.g. delete cargo before deleting its manifest)
  → The app shows the database error message to help you understand what to delete first
