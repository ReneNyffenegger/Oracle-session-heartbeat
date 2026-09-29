# Oracle Session Heartbeat

## 📝 Description

*Oracle Session Heartbeat* provides two clients for monitoring Oracle session
continuity and detecting idle-connection failures with SQL*Plus and
Oracle.ManagedDataAccess.

Each client registers a database session, commits periodic heartbeat rows, and
reconnects after client-side session termination so observed gaps can be
correlated with network or database timeout behavior.

## 📦 Installation and 🗑️ Deinstallation

Run [`_install.sql`](_install.sql) to install and [`_uninstall.sql`](_uninstall.sql) to deinstall the necessary tables and views.

For the powershell script, the location of the managed data access DLL needs to be known (`-oracleManagedDataAccessPath`).

## ▶️ Run scripts

```shell
$user     = 'rene'
$password = 'passw0rd1'
$db       = 'uat2'
$datasrc  = '(description=(address=(protocol=tcp)(Host=10.72.10.72)(Port=1521))(connect_data=(service_name=uat2)))'
```

Run the heartbeat using SQL\*Plus:
```shell
.\run-sqlplus-heartbeat.ps1 `
   -connectString    "$user/$password@$db" `
   -clientId         'sqlplus on notebook' `
   -intervalSeconds   10
```


Run the heartbeat using Powershell and managed data access:
```
.\run-powershell-heartbeat.ps1  `
   -connectString               "user id=$user;password=$password;data source=$datasrc" `
   -clientId                    'powersh on notebook' `
   -intervalSeconds              10 `
   -oracleManagedDataAccessPath "$pwd\Oracle.ManagedDataAccess.18.15.1.dll"
```

## 🔎 Query Results

```sql
select
   *
from
   tq84_heartbeat_v
order by dt
   desc;
```
