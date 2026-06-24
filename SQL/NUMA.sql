/*
- Each NUMA node has it's own local memory. It's faster than assessing remote memory from another node
- SQL Server is NUMA-aware - it tries to keep threads and memory allocation within the same node for performance

- Soft-NUMA is splitting of physical NUMA nodes (CPU cores) into smaller logical NUMA nodes for better distribution
- If physical NUMA node has more that 8 CPUs, SQL Server will auto-split into multiple soft-NUMA <8 CPUs each
- Since SQL Server 2016 Soft-NUMA is set by default when a NUMA node has more than 8 schedulers.
*/

/*
- The configuration on PRIMARY node is incorrect - (unlike Secondary one).
- Always validate that the schedulers are evenly distributed across the NUMA nodes in SQL Server
*/

--run this on Primary replica vs Secondary replica

SELECT
    @@SERVERNAME, n.node_id AS numa_node,
    MIN(s.cpu_id) AS first_cpu,
    MAX(s.cpu_id) AS last_cpu,
    COUNT(s.cpu_id) AS cpu_count,
    STRING_AGG(CAST(s.cpu_id AS VARCHAR), ',') AS cpu_list
FROM sys.dm_os_nodes n
JOIN sys.dm_os_schedulers s ON n.node_id = s.parent_node_id
WHERE s.scheduler_id < 255
    AND s.status = 'VISIBLE ONLINE'
    AND n.node_state_desc = 'ONLINE'
GROUP BY n.node_id
ORDER BY n.node_id;

/*
This is typical physical NUMA node on standard virtual machine (it is shared by former DBA Lead\Director):
- NumaNode1-11CPU
- NumaNode2-11CPU
- NumaNode3-10CPU

P.S. The performance of the current PRIMARY node becomes bottleneck due to incorrect configuration
*/

--soft NUMA
SELECT @@SERVERNAME, name, value, value_in_use, minimum, maximum, [description], is_dynamic, is_advanced
FROM sys.configurations WITH (NOLOCK)
WHERE name = 'automatic soft-NUMA disabled'
ORDER BY name
OPTION (RECOMPILE);

SELECT @@SERVERNAME, cpu_count, numa_node_count, hyperthread_ratio, softnuma_configuration, softnuma_configuration_desc, virtual_machine_type_desc
FROM sys.dm_os_sys_info
