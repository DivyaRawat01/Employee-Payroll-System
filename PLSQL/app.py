"""Payroll Management System - Flask front-end for the Oracle PL/SQL backend."""
import os
import datetime
import oracledb
from flask import Flask, render_template, request, redirect, url_for, flash

app = Flask(__name__)
app.secret_key = "payroll-mini-project"

# =====================================================================
#  EDIT ONLY THIS BLOCK
# =====================================================================
DB_USER = "add your username"
DB_PASSWORD = "Add password"          # <-- CHANGE: only this line
DB_DSN = "add dsn"

# Not needed for FreeSQL, leave as None
WALLET_DIR = None
WALLET_PASSWORD = None
# =====================================================================


def get_conn():
    if WALLET_DIR:
        return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN,
                                config_dir=WALLET_DIR, wallet_location=WALLET_DIR,
                                wallet_password=WALLET_PASSWORD)
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)


def to_month(text):
    """'2026-10' (from <input type=month>) -> date(2026, 10, 1)"""
    return datetime.datetime.strptime(text, "%Y-%m")


def clean_error(e):
    """Keep only the first line of an Oracle error, e.g. 'ORA-20010: Basic salary ...'"""
    return str(e).split("\n")[0]


def call_with_output(cur, proc, args):
    """Call a stored procedure and return what it printed with DBMS_OUTPUT."""
    cur.callproc("dbms_output.enable", [1000000])
    cur.callproc(proc, args)
    lines = []
    line = cur.var(str, 400)
    status = cur.var(int)
    while True:
        cur.callproc("dbms_output.get_line", (line, status))
        if status.getvalue() != 0:
            break
        lines.append(line.getvalue())
    return lines


@app.route("/")
def home():
    return redirect(url_for("employee"))


# ---------------- Page 1: Employee Details ----------------
@app.route("/employee", methods=["GET", "POST"])
def employee():
    conn = get_conn()
    cur = conn.cursor()
    if request.method == "POST":
        try:
            cur.execute("SELECT NVL(MAX(emp_id), 100) + 1 FROM Employees")
            emp_id = cur.fetchone()[0]
            cur.execute(
                """INSERT INTO Employees (emp_id, emp_name, email, designation, dept_id)
                   VALUES (:1, :2, :3, :4, :5)""",
                [emp_id, request.form["emp_name"], request.form["email"],
                 request.form["designation"], int(request.form["dept_id"])])
            # Salary_Details trigger (trg_validate_salary) runs here
            cur.execute("INSERT INTO Salary_Details (emp_id, basic_salary) VALUES (:1, :2)",
                        [emp_id, float(request.form["basic_salary"])])
            conn.commit()
            flash(f"Employee {emp_id} added.", "ok")
        except oracledb.DatabaseError as e:
            conn.rollback()
            flash(clean_error(e), "error")
        return redirect(url_for("employee"))

    cur.execute("SELECT dept_id, dept_name FROM Departments ORDER BY dept_name")
    depts = cur.fetchall()
    cur.execute("""SELECT e.emp_id, e.emp_name, e.designation, d.dept_name, s.basic_salary
                   FROM Employees e
                   JOIN Departments d ON d.dept_id = e.dept_id
                   LEFT JOIN Salary_Details s ON s.emp_id = e.emp_id
                   ORDER BY e.emp_id""")
    employees = cur.fetchall()
    conn.close()
    return render_template("employee.html", depts=depts, employees=employees)


# ---------------- Page 2: Salary Processing ----------------
@app.route("/salary", methods=["GET", "POST"])
def salary():
    conn = get_conn()
    cur = conn.cursor()
    output = []
    if request.method == "POST":
        try:
            month = to_month(request.form["pay_month"])
            if request.form["action"] == "attendance":
                # Attendance trigger (trg_validate_attendance) runs here
                cur.execute(
                    """MERGE INTO Attendance a
                       USING (SELECT :emp AS emp_id, :mon AS att_month FROM dual) s
                       ON (a.emp_id = s.emp_id AND a.att_month = s.att_month)
                       WHEN MATCHED THEN UPDATE SET working_days = :wd, days_present = :dp
                       WHEN NOT MATCHED THEN INSERT (att_id, emp_id, att_month, working_days, days_present)
                            VALUES (seq_att.NEXTVAL, s.emp_id, s.att_month, :wd, :dp)""",
                    {"emp": int(request.form["emp_id"]), "mon": month,
                     "wd": int(request.form["working_days"]),
                     "dp": int(request.form["days_present"])})
                conn.commit()
                flash("Attendance saved.", "ok")
            else:
                output = call_with_output(cur, "sp_generate_payroll", [month])
                flash("Payroll procedure executed.", "ok")
        except oracledb.DatabaseError as e:
            conn.rollback()
            flash(clean_error(e), "error")

    cur.execute("SELECT emp_id, emp_name FROM Employees ORDER BY emp_id")
    employees = cur.fetchall()
    conn.close()
    return render_template("salary.html", employees=employees, output=output,
                           this_month=datetime.date.today().strftime("%Y-%m"))


# ---------------- Page 3: Payroll Report ----------------
@app.route("/report")
def report():
    month_text = request.args.get("pay_month", datetime.date.today().strftime("%Y-%m"))
    rows, total = [], 0
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""SELECT e.emp_id, e.emp_name, d.dept_name,
                          p.gross_salary, p.deductions, p.net_salary
                   FROM Payroll p
                   JOIN Employees e ON e.emp_id = p.emp_id
                   JOIN Departments d ON d.dept_id = e.dept_id
                   WHERE p.pay_month = :m
                   ORDER BY e.emp_id""", {"m": to_month(month_text)})
    rows = cur.fetchall()
    total = sum(r[5] for r in rows)
    conn.close()
    return render_template("report.html", rows=rows, total=total, month=month_text)


if __name__ == "__main__":
    app.run(debug=True)