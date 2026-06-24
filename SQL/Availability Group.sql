-- 1. Overall AG health
SELECT
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    ar.availability_mode_desc AS AvailabilityMode,
    ar.failover_mode_desc AS FailoverMode,
    ar.read_only_routing_url AS ReadOnlyRoutingURL,
    ag.cluster_type_desc AS ClusterTypeDesc,
    ars.role_desc AS CurrentRole,
    ars.operational_state_desc AS OperationalState,
    ars.connected_state_desc AS ConnectedState,
    ars.synchronization_health_desc AS SyncHealth
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name;

-- 2. Database sync status
SELECT
    ag.name AS AvailabilityGroupName,
    drs.database_id,
    db.name,
    ar.replica_server_name,
    ar.availability_mode_desc AS AvailabilityMode,
    drs.synchronization_state_desc AS SyncState,
    drs.synchronization_health_desc AS SyncHealth,
    drs.log_send_queue_size AS LogSendQueueKB,
    drs.log_send_rate AS LogSendRateKB,
    drs.redo_queue_size AS RedoQueueKB,
    drs.redo_rate AS RedoRateKB,
    drs.last_commit_time,
    DATEDIFF(ss, drs.last_commit_time, GETDATE()) AS SecondsBehindPrimary
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id
JOIN sys.databases db ON drs.database_id = db.database_id
ORDER BY ag.name, db.name, ar.replica_server_name;

-- 3.1 Determine current role
SELECT
    ag.name AS AvailabilityGroupName,
    ars.role_desc AS CurrentRole,
    CASE
        WHEN ars.role_desc = 'PRIMARY' THEN 'This is the Primary Replica'
        WHEN ars.role_desc = 'SECONDARY' THEN 'This is a Secondary Replica'
        ELSE 'Unknown Role'
    END AS RoleDescription
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
WHERE ar.replica_server_name = @@SERVERNAME;

-- 3.2
SELECT
    CASE
        WHEN sys.fn_hadr_is_primary_replica(DB_NAME()) = 1
        THEN 'This is the Primary Replica'
        WHEN sys.fn_hadr_is_primary_replica(DB_NAME()) = 0
        THEN 'This is the Secondary Replica'
    END

-- 4. Get connection info for applications
SELECT
    ag.name AS AvailabilityGroupName,
    agl.dns_name AS ListenerDNSName,
    agl.port AS ListenerPort,
    'Server=' + agl.dns_name + ',' + CAST(agl.port AS VARCHAR(10)) + ';Database='+DB_NAME()+';ApplicationIntent=ReadOnly' AS ReadOnlyConnectionString,
    'Server=' + agl.dns_name + ',' + CAST(agl.port AS VARCHAR(10)) + ';Database='+DB_NAME()+';' AS ReadWriteConnectionString
FROM sys.availability_groups ag
JOIN sys.availability_group_listeners agl ON ag.group_id = agl.group_id;

-- 5. AG performance counters
SELECT
    counter_name,
    instance_name,
    cntr_value,
    cntr_type
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Availability Replica%'
   OR object_name LIKE '%Database Replica%'
ORDER BY object_name, counter_name, instance_name;

-- 6. Comprehensive health check
WITH AGHealthCheck AS (
    SELECT
        ag.name AS AGName,
        ar.replica_server_name AS ReplicaServer,
        ars.role_desc AS Role,
        ars.operational_state_desc AS OpState,
        ars.connected_state_desc AS ConnState,
        ars.synchronization_health_desc AS SyncHealth,
        db.name AS DatabaseName,
        drs.synchronization_state_desc AS DBSyncState,
        drs.log_send_queue_size AS LogSendQueueKB, -- Number of log records of the primary DB that hasn't been sent to the secondary databases in KB
        drs.log_send_rate AS LogSendRate,          -- Average rate at which primary replica instance sent data during last active period, in KB/sec
        drs.redo_queue_size AS RedoQueueKB,        -- Number of log records in the log files of the secondary replica that aren't yet redone in data files, in KB
        drs.redo_rate AS RedoRate                  -- Average rate at which the log records are being redone on a given secondary database, in kilobytes KB/sec
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
    LEFT JOIN sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id
    LEFT JOIN sys.databases db ON drs.database_id = db.database_id
)
SELECT *,
    CASE
        WHEN OpState != 'ONLINE' OR ConnState != 'CONNECTED' OR SyncHealth != 'HEALTHY' THEN 'ISSUE'
        WHEN LogSendQueueKB > 10240 OR RedoQueueKB > 10240 THEN 'PERFORMANCE_CONCERN'
        ELSE 'HEALTHY'
    END AS HealthStatus
FROM AGHealthCheck
ORDER BY AGName, ReplicaServer, DatabaseName;

-- Run this on secondary replica
-- 7. Comprehensive redo thread monitoring
WITH RedoAnalysis AS (
    SELECT
        ag.name AS AGName,
        db.name AS DatabaseName,
        drs.redo_queue_size AS RedoQueueKB,
        drs.redo_rate AS RedoRateKB,
        drs.log_send_queue_size AS LogSendQueueKB,
        drs.log_send_rate AS LogSendRateKB,
        drs.last_redone_lsn AS LastRedoneLSNOnSecondary, --Actual LSN of the last log record that was redone on the secondary database.
        drs.last_redone_time,
        DATEDIFF(SECOND, drs.last_redone_time, GETDATE()) AS SecondsSinceLastRedo,
        CASE
            WHEN drs.redo_rate = 0 THEN 'STALLED'
            WHEN drs.redo_queue_size > 100000 THEN 'HIGH_QUEUE'
            WHEN drs.redo_queue_size > 50000 THEN 'MEDIUM_QUEUE'
            ELSE 'NORMAL'
        END AS RedoStatus
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id
    JOIN sys.databases db ON drs.database_id = db.database_id
    WHERE ar.replica_server_name = @@SERVERNAME
        AND drs.is_local = 1
)
SELECT *,
    CASE
        WHEN RedoRateKB > 0
        THEN CAST(RedoQueueKB / RedoRateKB AS INT)
        ELSE NULL
    END AS EstimatedCatchupTimeSeconds
FROM RedoAnalysis
ORDER BY RedoQueueKB DESC;
