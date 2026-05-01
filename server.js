// ============================================================
//  server.js — Maritime Port Management System Backend
//  Run: node server.js   (make sure MySQL is running first)
// ============================================================

const express = require('express');
const mysql   = require('mysql2/promise');
const cors    = require('cors');
const path    = require('path');

const app  = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── DB connection ────────────────────────────────────────────
// EDIT these if your MySQL credentials differ
const pool = mysql.createPool({
    host:     'localhost',
    user:     'root',
    password: '1234',          // <-- put your MySQL root password here
    database: 'maritime_port',
    waitForConnections: true,
    connectionLimit:    10
});

// Helper
async function q(sql, params = []) {
    const [rows] = await pool.execute(sql, params);
    return rows;
}

// ============================================================
//  SHIPS
// ============================================================
app.get('/api/ships', async (req, res) => {
    try {
        const rows = await q(`
            SELECT s.*, sc.company_name,
                   bv.cargo_class, bv.max_load,
                   t.liquid_type,  t.pressure_rating,
                   cs.teu_capacity, cs.reefer_slots
            FROM ship s
            JOIN shipping_company sc ON s.company_id = sc.company_id
            LEFT JOIN bulk_vessel   bv ON s.ship_imo = bv.ship_imo
            LEFT JOIN tanker         t  ON s.ship_imo = t.ship_imo
            LEFT JOIN container_ship cs ON s.ship_imo = cs.ship_imo
            ORDER BY s.ship_name`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/ships/:imo', async (req, res) => {
    try {
        const rows = await q(`
            SELECT s.*, sc.company_name,
                   bv.cargo_class, bv.max_load,
                   t.liquid_type,  t.pressure_rating,
                   cs.teu_capacity, cs.reefer_slots
            FROM ship s
            JOIN shipping_company sc ON s.company_id = sc.company_id
            LEFT JOIN bulk_vessel   bv ON s.ship_imo = bv.ship_imo
            LEFT JOIN tanker         t  ON s.ship_imo = t.ship_imo
            LEFT JOIN container_ship cs ON s.ship_imo = cs.ship_imo
            WHERE s.ship_imo = ?`, [req.params.imo]);
        if (!rows.length) return res.status(404).json({ error: 'Not found' });
        res.json(rows[0]);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/ships', async (req, res) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const { ship_imo, ship_name, flag_state, tonnage, ship_type, company_id,
                cargo_class, max_load, liquid_type, pressure_rating,
                teu_capacity, reefer_slots } = req.body;

        await conn.execute(
            `INSERT INTO ship (ship_imo,ship_name,flag_state,tonnage,ship_type,company_id)
             VALUES (?,?,?,?,?,?)`,
            [ship_imo, ship_name, flag_state, tonnage || null, ship_type, company_id]);

        if (ship_type === 'BULK')
            await conn.execute(`INSERT INTO bulk_vessel VALUES (?,?,?)`,
                [ship_imo, cargo_class || null, max_load || null]);
        if (ship_type === 'TANKER')
            await conn.execute(`INSERT INTO tanker VALUES (?,?,?)`,
                [ship_imo, liquid_type || null, pressure_rating || null]);
        if (ship_type === 'CONTAINER')
            await conn.execute(`INSERT INTO container_ship VALUES (?,?,?)`,
                [ship_imo, teu_capacity || null, reefer_slots || null]);

        await conn.commit();
        res.json({ success: true });
    } catch (e) {
        await conn.rollback();
        res.status(500).json({ error: e.message });
    } finally { conn.release(); }
});

app.put('/api/ships/:imo', async (req, res) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const { ship_name, flag_state, tonnage, company_id,
                cargo_class, max_load, liquid_type, pressure_rating,
                teu_capacity, reefer_slots } = req.body;
        const imo = req.params.imo;

        await conn.execute(
            `UPDATE ship SET ship_name=?,flag_state=?,tonnage=?,company_id=? WHERE ship_imo=?`,
            [ship_name, flag_state, tonnage || null, company_id, imo]);

        // update subtype rows if they exist
        await conn.execute(`UPDATE bulk_vessel   SET cargo_class=?,max_load=?        WHERE ship_imo=?`, [cargo_class||null, max_load||null, imo]);
        await conn.execute(`UPDATE tanker         SET liquid_type=?,pressure_rating=? WHERE ship_imo=?`, [liquid_type||null, pressure_rating||null, imo]);
        await conn.execute(`UPDATE container_ship SET teu_capacity=?,reefer_slots=?  WHERE ship_imo=?`, [teu_capacity||null, reefer_slots||null, imo]);

        await conn.commit();
        res.json({ success: true });
    } catch (e) {
        await conn.rollback();
        res.status(500).json({ error: e.message });
    } finally { conn.release(); }
});

app.delete('/api/ships/:imo', async (req, res) => {
    try {
        // Cascades handle subtypes
        await q(`DELETE FROM ship WHERE ship_imo=?`, [req.params.imo]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  SHIPPING COMPANIES
// ============================================================
app.get('/api/companies', async (req, res) => {
    try {
        const rows = await q(`SELECT * FROM shipping_company ORDER BY company_name`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/companies', async (req, res) => {
    try {
        const { company_name, country } = req.body;
        const result = await q(`INSERT INTO shipping_company (company_name,country) VALUES (?,?)`, [company_name, country]);
        res.json({ success: true, id: result.insertId });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/companies/:id', async (req, res) => {
    try {
        const { company_name, country } = req.body;
        await q(`UPDATE shipping_company SET company_name=?,country=? WHERE company_id=?`,
            [company_name, country, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/companies/:id', async (req, res) => {
    try {
        await q(`DELETE FROM shipping_company WHERE company_id=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  DOCKS
// ============================================================
app.get('/api/docks', async (req, res) => {
    try {
        const rows = await q(`SELECT * FROM dock ORDER BY dock_name`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/docks', async (req, res) => {
    try {
        const { dock_name, dock_type, max_capacity } = req.body;
        const r = await q(`INSERT INTO dock (dock_name,dock_type,max_capacity) VALUES (?,?,?)`,
            [dock_name, dock_type, max_capacity||null]);
        res.json({ success: true, id: r.insertId });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/docks/:id', async (req, res) => {
    try {
        const { dock_name, dock_type, max_capacity } = req.body;
        await q(`UPDATE dock SET dock_name=?,dock_type=?,max_capacity=? WHERE dock_id=?`,
            [dock_name, dock_type, max_capacity||null, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/docks/:id', async (req, res) => {
    try {
        await q(`DELETE FROM dock WHERE dock_id=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  PORT WORKERS
// ============================================================
app.get('/api/workers', async (req, res) => {
    try {
        const rows = await q(`
            SELECT pw.*,
                   sup.worker_name AS supervisor_name,
                   IF(dw.worker_id IS NOT NULL, 1, 0) AS is_dock_worker,
                   IF(co.worker_id IS NOT NULL, 1, 0) AS is_crane_operator,
                   IF(io.worker_id IS NOT NULL, 1, 0) AS is_inspection_officer,
                   dw.assigned_zone, co.crane_licence, io.badge_no
            FROM port_worker pw
            LEFT JOIN port_worker sup ON pw.supervisor_id = sup.worker_id
            LEFT JOIN dock_worker       dw ON pw.worker_id = dw.worker_id
            LEFT JOIN crane_operator    co ON pw.worker_id = co.worker_id
            LEFT JOIN inspection_officer io ON pw.worker_id = io.worker_id
            ORDER BY pw.worker_name`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/workers', async (req, res) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const { worker_name, shift_type, supervisor_id,
                is_dock_worker, assigned_zone,
                is_crane_operator, crane_licence,
                is_inspection_officer, badge_no } = req.body;

        const [r] = await conn.execute(
            `INSERT INTO port_worker (worker_name,shift_type,supervisor_id) VALUES (?,?,?)`,
            [worker_name, shift_type, supervisor_id||null]);
        const wid = r.insertId;

        if (is_dock_worker)
            await conn.execute(`INSERT INTO dock_worker VALUES (?,?)`, [wid, assigned_zone||null]);
        if (is_crane_operator)
            await conn.execute(`INSERT INTO crane_operator VALUES (?,?)`, [wid, crane_licence||null]);
        if (is_inspection_officer)
            await conn.execute(`INSERT INTO inspection_officer VALUES (?,?)`, [wid, badge_no]);

        await conn.commit();
        res.json({ success: true, id: wid });
    } catch (e) {
        await conn.rollback();
        res.status(500).json({ error: e.message });
    } finally { conn.release(); }
});

app.put('/api/workers/:id', async (req, res) => {
    try {
        const { worker_name, shift_type, supervisor_id } = req.body;
        await q(`UPDATE port_worker SET worker_name=?,shift_type=?,supervisor_id=? WHERE worker_id=?`,
            [worker_name, shift_type, supervisor_id||null, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/workers/:id', async (req, res) => {
    try {
        await q(`DELETE FROM port_worker WHERE worker_id=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  CARGO
// ============================================================
app.get('/api/cargo', async (req, res) => {
    try {
        const rows = await q(`
            SELECT c.*,
                   co.owner_type,
                   COALESCE(p.person_name, ce.company_name, g.govt_name) AS owner_name,
                   m.issue_date AS manifest_date,
                   ci.outcome  AS inspection_outcome
            FROM cargo c
            JOIN cargo_owner co ON c.owner_id = co.owner_id
            LEFT JOIN person         p  ON co.person_id   = p.person_id
            LEFT JOIN company_entity ce ON co.company_reg = ce.company_reg
            LEFT JOIN government     g  ON co.govt_code   = g.govt_code
            JOIN manifest            m  ON c.manifest_no  = m.manifest_no
            LEFT JOIN customs_inspection ci ON c.inspection_id = ci.inspection_id
            ORDER BY c.cargo_id`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/cargo', async (req, res) => {
    try {
        const { cargo_type, weight_kg, owner_id, manifest_no, quantity, inspection_id } = req.body;
        const r = await q(
            `INSERT INTO cargo (cargo_type,weight_kg,owner_id,manifest_no,quantity,inspection_id)
             VALUES (?,?,?,?,?,?)`,
            [cargo_type, weight_kg||null, owner_id, manifest_no, quantity||1, inspection_id||null]);
        res.json({ success: true, id: r.insertId });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/cargo/:id', async (req, res) => {
    try {
        const { cargo_type, weight_kg, quantity } = req.body;
        await q(`UPDATE cargo SET cargo_type=?,weight_kg=?,quantity=? WHERE cargo_id=?`,
            [cargo_type, weight_kg||null, quantity||1, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/cargo/:id', async (req, res) => {
    try {
        await q(`DELETE FROM cargo WHERE cargo_id=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  MANIFESTS
// ============================================================
app.get('/api/manifests', async (req, res) => {
    try {
        const rows = await q(`
            SELECT m.*, s.ship_name, sc.company_name
            FROM manifest m
            JOIN ship s ON m.ship_imo = s.ship_imo
            JOIN shipping_company sc ON m.company_id = sc.company_id
            ORDER BY m.manifest_no`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/manifests', async (req, res) => {
    try {
        const { issue_date, ship_imo, company_id } = req.body;
        const r = await q(`INSERT INTO manifest (issue_date,ship_imo,company_id) VALUES (?,?,?)`,
            [issue_date, ship_imo, company_id]);
        res.json({ success: true, id: r.insertId });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/manifests/:id', async (req, res) => {
    try {
        const { issue_date, ship_imo, company_id } = req.body;
        await q(`UPDATE manifest SET issue_date=?,ship_imo=?,company_id=? WHERE manifest_no=?`,
            [issue_date, ship_imo, company_id, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/manifests/:id', async (req, res) => {
    try {
        await q(`DELETE FROM manifest WHERE manifest_no=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  CUSTOMS INSPECTIONS
// ============================================================
app.get('/api/inspections', async (req, res) => {
    try {
        const rows = await q(`
            SELECT ci.*, pw.worker_name
            FROM customs_inspection ci
            LEFT JOIN inspection_officer io ON ci.worker_id = io.worker_id
            LEFT JOIN port_worker pw ON io.worker_id = pw.worker_id
            ORDER BY ci.inspection_id`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/inspections', async (req, res) => {
    try {
        const { insp_date, outcome, inspector_name, worker_id } = req.body;
        const r = await q(
            `INSERT INTO customs_inspection (insp_date,outcome,inspector_name,worker_id) VALUES (?,?,?,?)`,
            [insp_date, outcome, inspector_name, worker_id||null]);
        res.json({ success: true, id: r.insertId });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/inspections/:id', async (req, res) => {
    try {
        const { insp_date, outcome, inspector_name } = req.body;
        await q(`UPDATE customs_inspection SET insp_date=?,outcome=?,inspector_name=? WHERE inspection_id=?`,
            [insp_date, outcome, inspector_name, req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/inspections/:id', async (req, res) => {
    try {
        await q(`DELETE FROM customs_inspection WHERE inspection_id=?`, [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  SCHEDULES
// ============================================================
app.get('/api/schedules', async (req, res) => {
    try {
        const rows = await q(`
            SELECT sch.*, d.dock_name
            FROM schedule sch
            JOIN dock d ON sch.dock_id = d.dock_id
            ORDER BY sch.arrival_time DESC`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/schedules', async (req, res) => {
    try {
        const { sched_no, dock_id, arrival_time, departure_time, status } = req.body;
        await q(`INSERT INTO schedule VALUES (?,?,?,?,?)`,
            [sched_no, dock_id, arrival_time||null, departure_time||null, status]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/schedules/:sched_no/:dock_id', async (req, res) => {
    try {
        const { arrival_time, departure_time, status } = req.body;
        await q(`UPDATE schedule SET arrival_time=?,departure_time=?,status=? WHERE sched_no=? AND dock_id=?`,
            [arrival_time||null, departure_time||null, status, req.params.sched_no, req.params.dock_id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/schedules/:sched_no/:dock_id', async (req, res) => {
    try {
        await q(`DELETE FROM schedule WHERE sched_no=? AND dock_id=?`,
            [req.params.sched_no, req.params.dock_id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  CARGO OWNERS (read + create)
// ============================================================
app.get('/api/cargo-owners', async (req, res) => {
    try {
        const rows = await q(`
            SELECT co.*,
                   COALESCE(p.person_name, ce.company_name, g.govt_name) AS display_name
            FROM cargo_owner co
            LEFT JOIN person         p  ON co.person_id   = p.person_id
            LEFT JOIN company_entity ce ON co.company_reg = ce.company_reg
            LEFT JOIN government     g  ON co.govt_code   = g.govt_code
            ORDER BY co.owner_id`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============================================================
//  BERTHS AT (junction — read + create)
// ============================================================
app.get('/api/berths', async (req, res) => {
    try {
        const rows = await q(`
            SELECT ba.*, d.dock_name, s.ship_name
            FROM berths_at ba
            JOIN dock d ON ba.dock_id = d.dock_id
            JOIN ship s ON ba.ship_imo = s.ship_imo
            ORDER BY ba.berth_date DESC`);
        res.json(rows);
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/berths', async (req, res) => {
    try {
        const { dock_id, ship_imo, berth_date, berth_duration } = req.body;
        await q(`INSERT INTO berths_at VALUES (?,?,?,?)`,
            [dock_id, ship_imo, berth_date, berth_duration||null]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/berths/:dock_id/:ship_imo/:berth_date', async (req, res) => {
    try {
        await q(`DELETE FROM berths_at WHERE dock_id=? AND ship_imo=? AND berth_date=?`,
            [req.params.dock_id, req.params.ship_imo, req.params.berth_date]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ── Start ────────────────────────────────────────────────────
app.listen(PORT, () =>
    console.log(`\n  Maritime Port System running → http://localhost:${PORT}\n`));
