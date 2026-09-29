using namespace Oracle.ManagedDataAccess.Client
using namespace System.Data

[cmdletBinding()]
param(
   [string]$connectString              ,
   [string]$oracleManagedDataAccessPath,
   [string]$ClientId                     = 'Oracle.ManagedDataAccess',
   [int   ]$intervalSeconds              =  300,
   [int   ]$reconnectDelaySeconds        =  300
)

function write-log {
   param( [string] $msg)

   write-host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
}

function open-oracleConnection {
   param( [string] $connectString)

   $connection = [OracleConnection]::new($connectString)
   $connection.Open()
   return $connection
}

function new-oracleCommand {
   param(
      [OracleConnection]$Connection,
      [string          ]$CommandText
   )

   $command = $Connection.CreateCommand()
   $command.BindByName  = $true
   $command.CommandText = $CommandText
   return $command
}

function new-oracleParameter {
   param(
      [string]$Name,
      [OracleDbType]$Type,
      [ParameterDirection]$Direction,
      $Value
   )

   $parameter = [OracleParameter]::new()
   $parameter.ParameterName = $Name
   $parameter.OracleDbType  = $Type
   $parameter.Direction     = $Direction

   if ($Direction -ne [ParameterDirection]::Output) {
      $parameter.Value = $Value
   }

   return $parameter
}

function register-session {
   param(
      [OracleConnection] $Connection,
      [string          ] $sessionClientId
   )

 #
 # Register the new Oracle.ManagedDataAccess session and return its id.
 #
   $command = new-oracleCommand -connection $connection -CommandText @'
begin

   insert into tq84_heartbeat_session (client_id) values (:client_id) returning id into :id;
   commit;
end;
'@

   try {
      $null = $command.Parameters.Add((New-OracleParameter -name 'client_id' -type ([OracleDbType]::Varchar2) -Direction ([ParameterDirection]::Input ) -Value $SessionClientId))
      $null = $command.Parameters.Add((New-OracleParameter -name 'id'        -type ([OracleDbType]::Int64)    -Direction ([ParameterDirection]::Output) -Value $null           ))

      $null = $command.ExecuteNonQuery()
      return [int64]$command.Parameters['id'].Value.ToString()
   }
   finally {
      $command.Dispose()
   }
}


# add-type -assemblyName Oracle.ManagedDataAccess
  add-type -path         $oracleManagedDataAccessPath

while ($true) {
   $connection = $null

   try {
      $connection = open-oracleConnection -connectString $connectString
      $sessionId  = register-session      -connection    $connection -sessionClientId $ClientId

    #
    # Insert the session heartbeat and commit it immediately.
    #
      $cmdPing = new-oracleCommand -connection $connection -CommandText @'
      begin
         insert into tq84_heartbeat_ping(id_session) values (:id_session);
         commit;
      end;
'@
      $null = $cmdPing.Parameters.Add((new-oracleParameter -name 'id_session' -Type ([OracleDbType]::Int64) -Direction ([ParameterDirection]::Input) -Value $SessionId))
      write-log "Registered session $sessionId."

      while ($connection.State -eq [ConnectionState]::Open) {
         $null = $cmdPing.ExecuteNonQuery()
         write-log "Committed ping for session $sessionId, going to sleep for $intervalSeconds seconds"
         start-sleep -seconds $intervalSeconds
      }

      throw 'Oracle connection is no longer open.'
   }
   catch {
      write-log "Oracle.ManagedDataAccess connection failed: $($_.Exception.Message)"
      start-sleep -seconds $reconnectDelaySeconds
   }
   finally {
      if ($connection) {
         $connection.Dispose()
      }
   }
}
