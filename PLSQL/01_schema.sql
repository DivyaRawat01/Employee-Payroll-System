-- ============================================
-- PAYROLL MANAGEMENT SYSTEM (Oracle SQL / PL-SQL)
-- File 1: Tables + sample data
-- ============================================

CREATE TABLE Departments (
    dept_id    NUMBER PRIMARY KEY,
    dept_name  VARCHAR2(50) NOT NULL UNIQUE
);

CREATE TABLE Employees (
    emp_id       NUMBER PRIMARY KEY,
    emp_name     VARCHAR2(60) NOT NULL,
    email        VARCHAR2(80) UNIQUE,
    designation  VARCHAR2(50),
    hire_date    DATE DEFAULT SYSDATE,
    dept_id      NUMBER NOT NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id) REFERENCES Departments(dept_id)
);

CREATE TABLE Attendance (
    att_id        NUMBER PRIMARY KEY,
    emp_id        NUMBER NOT NULL,
    att_month     DATE NOT NULL,            -- first day of month, e.g. 01-OCT-2026
    working_days  NUMBER(2) NOT NULL,
    days_present  NUMBER(2) NOT NULL,
    CONSTRAINT fk_att_emp FOREIGN KEY (emp_id) REFERENCES Employees(emp_id),
    CONSTRAINT uq_att UNIQUE (emp_id, att_month)
);

CREATE TABLE Salary_Details (
    emp_id        NUMBER PRIMARY KEY,
    basic_salary  NUMBER(10,2) NOT NULL,
    hra_percent   NUMBER(5,2) DEFAULT 20,
    da_percent    NUMBER(5,2) DEFAULT 10,
    pf_percent    NUMBER(5,2) DEFAULT 12,
    CONSTRAINT fk_sal_emp FOREIGN KEY (emp_id) REFERENCES Employees(emp_id)
);

CREATE TABLE Payroll (
    payroll_id    NUMBER PRIMARY KEY,
    emp_id        NUMBER NOT NULL,
    pay_month     DATE NOT NULL,
    gross_salary  NUMBER(10,2),
    deductions    NUMBER(10,2),
    net_salary    NUMBER(10,2),
    generated_on  DATE DEFAULT SYSDATE,
    CONSTRAINT fk_pay_emp FOREIGN KEY (emp_id) REFERENCES Employees(emp_id),
    CONSTRAINT uq_pay UNIQUE (emp_id, pay_month)
);

CREATE SEQUENCE seq_att START WITH 1;
CREATE SEQUENCE seq_payroll START WITH 1;

-- ---------- Sample data ----------
INSERT INTO Departments VALUES (1, 'IT');
INSERT INTO Departments VALUES (2, 'HR');
INSERT INTO Departments VALUES (3, 'Finance');

INSERT INTO Employees VALUES (101, 'Amit Sharma', 'amit@corp.com', 'Developer', DATE '2024-01-10', 1);
INSERT INTO Employees VALUES (102, 'Neha Singh',  'neha@corp.com', 'HR Executive', DATE '2023-06-15', 2);
INSERT INTO Employees VALUES (103, 'Ravi Kumar',  'ravi@corp.com', 'Accountant', DATE '2022-09-01', 3);

INSERT INTO Salary_Details (emp_id, basic_salary) VALUES (101, 40000);
INSERT INTO Salary_Details (emp_id, basic_salary) VALUES (102, 30000);
INSERT INTO Salary_Details (emp_id, basic_salary) VALUES (103, 35000);

INSERT INTO Attendance VALUES (seq_att.NEXTVAL, 101, DATE '2026-10-01', 26, 25);
INSERT INTO Attendance VALUES (seq_att.NEXTVAL, 102, DATE '2026-10-01', 26, 26);
INSERT INTO Attendance VALUES (seq_att.NEXTVAL, 103, DATE '2026-10-01', 26, 22);

COMMIT;
