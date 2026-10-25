HOW TO RUN
1. Run 01_schema.sql and 02_plsql.sql in SQL Developer (same user you will use below).
2. Install Python 3.9+ and then:   pip install -r requirements.txt
3. Open app.py and set DB_USER, DB_PASSWORD, DB_DSN
   (Oracle XE: localhost:1521/XEPDB1   |  older XE 11g: localhost:1521/XE)
4. Run:   python app.py
5. Open http://127.0.0.1:5000

ORACLE CLOUD FREE TIER (Autonomous Database)
Set these before "python app.py" (Windows PowerShell shown):
  $env:ORA_USER="ADMIN"
  $env:ORA_PASSWORD="your admin password"
  $env:ORA_DSN="mydb_high"                 # a service name from tnsnames.ora in the wallet
  $env:ORA_WALLET_DIR="C:\wallet"          # folder where you unzipped the wallet
  $env:ORA_WALLET_PASSWORD="wallet password"
