-- ============================================
-- File 2: PL/SQL  (functions, procedures, cursors, triggers, exceptions)
-- Run in SQL*Plus / SQL Developer. Use:  SET SERVEROUTPUT ON
-- ============================================

-- ---------- 1. FUNCTION: gross salary = basic + HRA + DA ----------
CREATE OR REPLACE FUNCTION fn_gross_salary (p_emp_id NUMBER)
RETURN NUMBER
IS
    v_basic Salary_Details.basic_salary%TYPE;
    v_hra   Salary_Details.hra_percent%TYPE;
    v_da    Salary_Details.da_percent%TYPE;
BEGIN
    SELECT basic_salary, hra_percent, da_percent
    INTO   v_basic, v_hra, v_da
    FROM   Salary_Details
    WHERE  emp_id = p_emp_id;

    RETURN v_basic + (v_basic * v_hra / 100) + (v_basic * v_da / 100);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'No salary details for employee ' || p_emp_id);
END fn_gross_salary;
/

-- ---------- 2. FUNCTION: deductions = PF + absent-day cut ----------
CREATE OR REPLACE FUNCTION fn_deductions (p_emp_id NUMBER, p_month DATE)
RETURN NUMBER
IS
    v_basic    Salary_Details.basic_salary%TYPE;
    v_pf       Salary_Details.pf_percent%TYPE;
    v_working  Attendance.working_days%TYPE;
    v_present  Attendance.days_present%TYPE;
    v_absent_cut NUMBER;
BEGIN
    SELECT basic_salary, pf_percent INTO v_basic, v_pf
    FROM   Salary_Details WHERE emp_id = p_emp_id;

    SELECT working_days, days_present INTO v_working, v_present
    FROM   Attendance
    WHERE  emp_id = p_emp_id AND att_month = TRUNC(p_month, 'MM');

    v_absent_cut := (v_basic / v_working) * (v_working - v_present);
    RETURN (v_basic * v_pf / 100) + v_absent_cut;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Salary/attendance missing for employee ' || p_emp_id);
END fn_deductions;
/

-- ---------- 3. PROCEDURE: generate payroll for a month (uses CURSOR) ----------
CREATE OR REPLACE PROCEDURE sp_generate_payroll (p_month DATE)
IS
    CURSOR c_emp IS SELECT emp_id FROM Employees;
    v_gross  NUMBER;
    v_deduct NUMBER;
    v_count  NUMBER := 0;
BEGIN
    FOR r IN c_emp LOOP
        BEGIN
            v_gross  := fn_gross_salary(r.emp_id);
            v_deduct := fn_deductions(r.emp_id, p_month);

            INSERT INTO Payroll (payroll_id, emp_id, pay_month, gross_salary, deductions, net_salary)
            VALUES (seq_payroll.NEXTVAL, r.emp_id, TRUNC(p_month, 'MM'),
                    v_gross, v_deduct, v_gross - v_deduct);
            v_count := v_count + 1;

        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                DBMS_OUTPUT.PUT_LINE('Payroll already exists for employee ' || r.emp_id);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Skipped employee ' || r.emp_id || ': ' || SQLERRM);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Payroll generated for ' || v_count || ' employees.');
END sp_generate_payroll;
/

-- ---------- 4. PROCEDURE: employee payroll report (explicit CURSOR) ----------
CREATE OR REPLACE PROCEDURE sp_payroll_report (p_month DATE)
IS
    CURSOR c_rep IS
        SELECT e.emp_id, e.emp_name, d.dept_name,
               p.gross_salary, p.deductions, p.net_salary
        FROM   Payroll p
        JOIN   Employees e   ON e.emp_id  = p.emp_id
        JOIN   Departments d ON d.dept_id = e.dept_id
        WHERE  p.pay_month = TRUNC(p_month, 'MM')
        ORDER  BY e.emp_id;
    v_rec   c_rep%ROWTYPE;
    v_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('PAYROLL REPORT - ' || TO_CHAR(p_month, 'MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE(RPAD('ID',6) || RPAD('Name',16) || RPAD('Dept',10) ||
                         RPAD('Gross',12) || RPAD('Deduct',12) || 'Net');
    OPEN c_rep;
    LOOP
        FETCH c_rep INTO v_rec;
        EXIT WHEN c_rep%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(RPAD(v_rec.emp_id,6) || RPAD(v_rec.emp_name,16) ||
                             RPAD(v_rec.dept_name,10) || RPAD(v_rec.gross_salary,12) ||
                             RPAD(v_rec.deductions,12) || v_rec.net_salary);
        v_total := v_total + v_rec.net_salary;
    END LOOP;

    IF c_rep%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No payroll found. Run sp_generate_payroll first.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total net payout: ' || v_total);
    END IF;
    CLOSE c_rep;
END sp_payroll_report;
/

-- ---------- 5. TRIGGER: validate salary ----------
CREATE OR REPLACE TRIGGER trg_validate_salary
BEFORE INSERT OR UPDATE ON Salary_Details
FOR EACH ROW
BEGIN
    IF :NEW.basic_salary < 10000 THEN
        RAISE_APPLICATION_ERROR(-20010, 'Basic salary cannot be below 10000');
    END IF;
    IF :NEW.pf_percent > 20 THEN
        RAISE_APPLICATION_ERROR(-20011, 'PF percent cannot exceed 20');
    END IF;
END;
/

-- ---------- 6. TRIGGER: validate attendance ----------
CREATE OR REPLACE TRIGGER trg_validate_attendance
BEFORE INSERT OR UPDATE ON Attendance
FOR EACH ROW
BEGIN
    IF :NEW.days_present > :NEW.working_days THEN
        RAISE_APPLICATION_ERROR(-20020, 'Days present cannot exceed working days');
    END IF;
END;
/

-- ============================================
-- TESTING
-- ============================================
SET SERVEROUTPUT ON

EXEC sp_generate_payroll(DATE '2026-10-01');
EXEC sp_payroll_report(DATE '2026-10-01');

-- Test trigger (should give error ORA-20010):
-- UPDATE Salary_Details SET basic_salary = 5000 WHERE emp_id = 101;

-- Test attendance trigger (should give error ORA-20020):
-- INSERT INTO Attendance VALUES (seq_att.NEXTVAL, 101, DATE '2026-11-01', 26, 30);
