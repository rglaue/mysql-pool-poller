--[[
    Copyright 2007 Russell E Glaue
    Center for the Application of Information Technologies
    Western Illinois University
--]]

function print_any_table( tt )
    -- Print anything - including nested tables
    function table_print (tt, indent, done)
        done = done or {}
        indent = indent or 0
        if type(tt) == "table" then
            -- for key, value in pairs (table.sort(tt)) do
            for key, value in pairs (tt) do
                io.write(string.rep (" ", indent)) -- indent it
                if type (value) == "table" and not done [value] then
                    done [value] = true
                    io.write(string.format("[%s] => table\n", tostring (key)));
                    io.write(string.rep (" ", indent+4)) -- indent it
                    io.write("(\n");
                    table_print (value, indent + 7, done)
                    io.write(string.rep (" ", indent+4)) -- indent it
                    io.write(")\n");
                else
                    io.write(string.format("[%s] => %s\n", tostring (key), tostring(value)))
                end
            end
        else
            io.write(tt .. "\n")
        end
    end
end

--[[
     debug
     - debug level; 0 = off, >0 = on
     levels.status {}
     - the status levels used
     nodes {}
     - the table of server nodes
     RW
     - the server types allowed for read-write queries
       the value is 0 (do not use) and >0 (use it)
       the value is a weight, with 1 being highest weight or the one to be used first.
     RO
     - the server types allowed for read-only queries
       the value is the same as used in RW
     RWupstatus
     - the value is the minimum status level the node must have for MySQL Proxy to
       evaluate it as UP as a read-write node
     ROupstatus
     - the value is the minimum status level the node must have for MySQL Proxy to
       evaluate it as UP as a read-only node
     lbmethod
     - rr = round robin
     - lc = least connections
     - wc = weighted connections
     - wlc = weighted least connections
--]]

if not proxy.global.config.mpp then
    proxy.global.config.mpp = {
        proxy_cache = true,
        rr_val = 0,
        nodes = {},
        debug = 1,
        levels = {
            type = {
                PRIMARY = 0,
                SECONDARY = 1
            },
            state = {
                UNKNOWN = 0,
                ACTIVE = 1,
                STANDBY = 2,
                FAIL_ONLINE = 3,
                FAIL_OFFLINE = 4
            },
            status = {
                UNKNOWN = 0,
                OK = 1,
                OK_INFO = 2,
                OK_WARN = 3,
                OK_CRITICAL = 4,
                FAIL = 5
            },
            by_number = {
                proxy_type = {},
                proxy_state = {},
                mpp_type = {},
                mpp_state = {},
                mpp_status = {},
            },
        },
        RW = {
            ACTIVE = 1,
            STANDBY = 0
        },
        RWupstatus = 2,
        RO = {
            ACTIVE = 2,
            STANDBY = 1
        },
        ROupstatus = 1,
        lbmethod = "rr"
    }
    -- reverse map MySQL Proxy type and state
        proxy.global.config.mpp.levels.by_number.proxy_type[proxy.BACKEND_TYPE_UNKNOWN] = "BACKEND_TYPE_UNKNOWN";
        proxy.global.config.mpp.levels.by_number.proxy_type[proxy.BACKEND_TYPE_RW] = "BACKEND_TYPE_RW";
        proxy.global.config.mpp.levels.by_number.proxy_type[proxy.BACKEND_TYPE_RO] = "BACKEND_TYPE_RO";
        proxy.global.config.mpp.levels.by_number.proxy_state[proxy.BACKEND_STATE_UNKNOWN] = "BACKEND_STATE_UNKNOWN";
        proxy.global.config.mpp.levels.by_number.proxy_state[proxy.BACKEND_STATE_UP] = "BACKEND_STATE_UP";
        proxy.global.config.mpp.levels.by_number.proxy_state[proxy.BACKEND_STATE_DOWN] = "BACKEND_STATE_DOWN";
    -- reverse map the MPP type, state and status
    for mpp_type, num in pairs (proxy.global.config.mpp.levels.type) do
        proxy.global.config.mpp.levels.by_number.mpp_type[num] = mpp_type;
    end
    for mpp_state, num in pairs (proxy.global.config.mpp.levels.state) do
        proxy.global.config.mpp.levels.by_number.mpp_state[num] = mpp_state;
    end
    for mpp_status, num in pairs (proxy.global.config.mpp.levels.status) do
        proxy.global.config.mpp.levels.by_number.mpp_status[num] = mpp_status;
    end
end

function load_balance(TYPE)
    -- TYPE is RW or RO for load balacing options
    -- load balance negotiation by TYPE is not supported yet
    local mpp = proxy.global.config.mpp

    local rr_node = proxy.global.config.mpp.rr_val
    if mpp.debug >= 2 then
        print("proxy.global.config.mpp.rr_val = " .. proxy.global.config.mpp.rr_val)
    end

    -- implement round robin of RW servers (currently 1 server for failover strategy)
    -- it is kind of funny to implement round robin when you know there is only one server
    -- however, we want this implemented so it can be used for multiple RO standby servers
    local gotserver = 0
    local rr_node_count = 0
    rr_node = rr_node + 1
    if (rr_node > (#proxy.backends)) then
        rr_node = 1
    end
    if mpp.debug >= 1 then
        print ("** entering round robin load balance negotiation **")
    end
    while not ((gotserver == 1) or (rr_node_count == (#proxy.backends))) do
        if mpp.debug >= 2 then
            print ("iteration: " .. rr_node_count)
        end
        if (mpp.nodes[proxy.backends[rr_node].address] == nil) then
            gotserver = 1 -- not really, we are giving out node 0 until we are initialized
            rr_node = 0
            if mpp.debug >= 1 then
                print("MPP table not yet initialized, allowing first connections to proxy backend 0.")
            end
            break
        end
        if mpp.debug >= 1 then
            local rr_node_address = proxy.backends[rr_node].address
            print(string.format("[ evaluating backend node = %s ]", rr_node))
            print(string.format(" -- node state requirement: %s", mpp.levels.state["ACTIVE"]))
            print(string.format(" -- node %s state: %s", rr_node_address, mpp.nodes[rr_node_address].state))
            print(string.format(" -- node status requirement: %s", mpp.RWupstatus))
            print(string.format(" -- node %s status: %s", rr_node_address, mpp.nodes[rr_node_address].status))
        end
        if ((proxy.backends[rr_node])
            and (mpp.nodes[proxy.backends[rr_node].address].state == mpp.levels.state["ACTIVE"])
            and (mpp.nodes[proxy.backends[rr_node].address].status <= mpp.RWupstatus))
        then
            if mpp.debug >= 1 then
                print("found ACTIVE UP backend at node: " .. rr_node)
            end
            gotserver = 1
            break
        elseif proxy.backends[(rr_node + 1)] then
            rr_node = rr_node + 1
            if mpp.debug >= 2 then
                print("incrementing node evaluation: " .. rr_node)
            end
            gotserver = 0
        else
            rr_node = 1
            if mpp.debug >= 2 then
                print("resetting node evaluation: " .. rr_node)
            end
            gotserver = 0
        end
        rr_node_count = rr_node_count + 1
    end
    if mpp.debug >= 1 then
        print ("** exiting round robin load balance negotiation **")
    end

    if gotserver == 1 then
        if mpp.debug >= 1 then
            print ("Setting rr_node: " .. rr_node)
        end
        proxy.global.config.mpp.rr_val = rr_node
    else
        rr_node = 0
    end

    return rr_node
end


function read_query( packet )
    local mpp = proxy.global.config.mpp

    if string.byte(packet) == proxy.COM_QUERY then
        local query = string.sub(packet, 2)

        -- parsing the query, and checking if it requests a MPP command
        -- expected syntax:
        --  MPP command
        --
        local com_type,command = string.match(query, "^%s*(%w+)%s+(%S.*)" )

        local command_error = 0
        local command_message = {}
        if com_type ~= nil and string.upper(com_type) == 'MPP' then
            if mpp.debug >= 1 then
                print("We got a MPP query: " .. command)
            end

            local tquery = {}
            local tqnum = 0;
            -- for word in string.gmatch(command, "%a+") do
            for word in string.gmatch(command, "%S+") do
                tqnum = tqnum + 1;
                if (tqnum == 1) then
                    tquery.action = string.upper(word)
                elseif   ((tquery.action == 'SET')
                   or (tquery.action == 'INITIALIZE')) then
                    if (tqnum == 2) then
                        tquery.node = string.lower(word)
                    elseif (tqnum == 3) then
                        tquery.key = string.upper(word)
                    elseif (tqnum == 4) then
                        tquery.val = string.upper(word)
                    end
                elseif (tquery.action == 'SHOW') then
                    if (tqnum == 2) then
                        tquery.node = string.upper(word)
                    elseif (tqnum == 3) then
                        tquery.key = string.upper(word)
                    end
                end
            end

            if   (((tquery.action == 'SET')
               or  (query.action == 'INITIALIZE'))
               and (tqnum ~= 4))   
            then
                command_error = 1
                table.insert( command_message, { string.format(
                "ERROR: the action %s requires 3 parameters but %s was provided.",
                tquery.action, tostring(tqnum)
                )})
            elseif (tquery.action == 'SHOW')
               and ((tqnum ~= 2) and (tqnum ~= 3))
            then
                command_error = 1
                table.insert( command_message, { string.format(
                "ERROR: the action %s requires 2 or 3 parameters but %s was provided.",
                tquery.action, tostring(tqnum)
                )})
            end
            
            if (tquery.action == 'INITIALIZE') then
                if (tquery.key == 'TYPE') then
                    if not proxy.global.config.mpp.levels.type[tquery.val] then
                        command_error = 1
                        table.insert( command_message, { string.format(
                        "ERROR: TYPE of %s not valid.",
                        tquery.val
                        )})
                    else
                        local proxynum = nil
                        for i = 1, #proxy.backends do
                            if (proxy.backends[i].address == tquery.node) then
                                proxynum = i
                                break
                            end
                        end
                        if not proxynum then
                            command_error = 1
                            table.insert( command_message, { string.format(
                            "ERROR: node %s is not configured in MySQL Proxy.",
                            tquery.node
                            )})
                        else
                            if not proxy.global.config.mpp.nodes[tquery.node] then
                                local nodenum = #proxy.global.config.mpp.nodes or 0;
                                nodenum = nodenum + 1
                                proxy.global.config.mpp.nodes[tquery.node] = {}
                                proxy.global.config.mpp.nodes[tquery.node].priority = nodenum
                            end
                            proxy.global.config.mpp.nodes[tquery.node].proxynum = proxynum
                            proxy.global.config.mpp.nodes[tquery.node].weight = 1
                            proxy.global.config.mpp.nodes[tquery.node].type =
                                proxy.global.config.mpp.levels.type[tquery.val]
                            proxy.global.config.mpp.nodes[tquery.node].state =
                                proxy.global.config.mpp.levels.state["UNKNOWN"]
                            proxy.global.config.mpp.nodes[tquery.node].status =
                                proxy.global.config.mpp.levels.status["UNKNOWN"]
                        end
                    end
                else
                    command_error = 1
                    table.insert( command_message, { string.format(
                        "Element %s is unrecognized, cannot initialize node %s.",
                        tquery.key, tquery.node
                    )})
                end
            end
            
            if (tquery.action == 'SET') then
                if not proxy.global.config.mpp.nodes[tquery.node] then
                    command_error = 1
                    table.insert( command_message, { string.format(
                                    "Cannot set elements of an uninitialized node %s.",
                        tquery.node
                    )})
                elseif (tquery.key == 'WEIGHT') then
                    if not tquery.val >= 0 then
                        command_error = 1
                        table.insert( command_message, { string.format(
                        "ERROR: WEIGHT of %s must be greater than or equal to 0.",
                        tquery.val
                        )})
                    else
                        proxy.global.config.mpp.nodes[tquery.node].weight = tquery.val
                    end
                elseif (tquery.key == 'TYPE') then
                    if not proxy.global.config.mpp.levels.type[tquery.val] then
                        command_error = 1
                        table.insert( command_message, { string.format(
                        "ERROR: TYPE of %s not valid.",
                        tquery.val
                        )})
                    else
                        proxy.global.config.mpp.nodes[tquery.node].type =
                        proxy.global.config.mpp.levels.type[tquery.val]
                    end
                elseif (tquery.key == 'STATE') then
                    if not proxy.global.config.mpp.levels.state[tquery.val] then
                        command_error = 1
                        table.insert( command_message, { string.format(
                        "ERROR: STATE of %s not valid.",
                        tquery.val
                        )})
                    else
                        proxy.global.config.mpp.nodes[tquery.node].state =
                            proxy.global.config.mpp.levels.state[tquery.val]
                    end
                elseif (tquery.key == 'STATUS') then
                    if not proxy.global.config.mpp.levels.status[tquery.val] then
                        command_error = 1
                        table.insert( command_message, { string.format(
                        "ERROR: STATUS of %s not valid.",
                        tquery.val
                        )})
                    else
                        proxy.global.config.mpp.nodes[tquery.node].status =
                            proxy.global.config.mpp.levels.status[tquery.val]
                    end
                else
                    command_error = 1
                    table.insert( command_message, { string.format(
                        "Unrecognized element %s cannot be set in node %s.",
                        tquery.key, tquery.node
                    )})
                end
            end
    
            if (tquery.action == 'SHOW') then
                if (tquery.node == 'ALL') then
                    for nodename, node in pairs (proxy.global.config.mpp.nodes) do
                        local proxynode
                        for i = 1, #proxy.backends do
                            if (proxy.backends[i].address == nodename) then
                                proxynode = proxy.backends[i]
                                break
                            end
                        end
                        table.insert(command_message, { nodename, "proxy", "type",    mpp.levels.by_number.proxy_type[proxynode.type] })
                        table.insert(command_message, { nodename, "proxy", "state",   mpp.levels.by_number.proxy_state[proxynode.state] })
                        table.insert(command_message, { nodename, "proxy", "address", proxynode.address })
                        table.insert(command_message, { nodename, "proxy", "connected_clients", proxynode.connected_clients })
                        table.insert(command_message, { nodename, "mpp",   "type",    mpp.levels.by_number.mpp_type[node.type] })
                        table.insert(command_message, { nodename, "mpp",   "state",   mpp.levels.by_number.mpp_state[node.state] })
                        table.insert(command_message, { nodename, "mpp",   "status",  mpp.levels.by_number.mpp_status[node.status] })
                        table.insert(command_message, { nodename, "mpp",   "weight",  node.weight })
                    end
                    proxy.response.type = proxy.MYSQLD_PACKET_OK
                    proxy.response.resultset = {
                        fields = {
                            { 
                                type = proxy.MYSQL_TYPE_STRING, 
                                name = "nodename",
                            },
                            { 
                                type = proxy.MYSQL_TYPE_STRING, 
                                name = "group",
                            },
                            { 
                                type = proxy.MYSQL_TYPE_STRING, 
                                name = "element",
                            },
                            { 
                                type = proxy.MYSQL_TYPE_STRING, 
                                name = "value",
                            }
                        },
                        rows = command_message,
                    }
                    return proxy.PROXY_SEND_RESULT
                else
                    command_error = 1
                    table.insert(command_message,  { string.format(
                        "Unrecognized option %s for SHOW.",
                        tquery.node
                    )})
                end
            end
    
            if command_error == 1 then
                -- 
                -- assembling the error message
                --
                proxy.response.type = proxy.MYSQLD_PACKET_OK
                proxy.response.resultset = {
                    fields = {
                        { 
                            type = proxy.MYSQL_TYPE_STRING, 
                            name = ("ERROR - " .. command),
                        }
                    },
                    rows = command_message,
                }
                return proxy.PROXY_SEND_RESULT
            else
                if not command_message[1] then
                    command_message[1] = { "SUCCESS" }
                end
                --
                -- assembling the result set
                --
                proxy.response.type = proxy.MYSQLD_PACKET_OK
                proxy.response.resultset = {
                    fields = {
                        { 
                            type = proxy.MYSQL_TYPE_STRING, 
                            name = command,
                        }
                    },
                    rows = command_message,
                }
                return proxy.PROXY_SEND_RESULT
            end
        else
            if mpp.debug >= 1 then
                print("We got a normal query: " .. query)
            end

            local servernode = load_balance("RW")
            if servernode >= 1 then
                if proxy.connection.backend_ndx == 0 then
                    -- then we load balance in the read_query()
                    proxy.connection.backend_ndx = servernode
                    if mpp.debug >= 1 then
                        print(string.format("read_query lb select: node %s",servernode))
                    end
                else
                    servernode = proxy.connection.backend_ndx
                    if mpp.debug >= 1 then
                        print(string.format("read_query continuing: node %s",servernode))
                    end
                end
            -- if servernode == 0 then there are no valid nodes
            elseif servernode == 0 then
                if query ~= nil and string.upper(query) == "SET AUTOCOMMIT=0" then
                    -- deal with DBD::mysql always setting autocommit on every connection
                    if mpp.debug >= 1 then
                        print("Ignoring SET AUTOCOMMIT=0 - mysql bug #32464");
                    end
                    proxy.response.type = proxy.MYSQLD_PACKET_OK
                    return proxy.PROXY_SEND_RESULT
                end
                out_msg = "MPP error: Cannot find a valid server node for connections!"
                if mpp.debug >= 1 then
                    io.write("MPP returning error: %s", out_msg)
                end
                proxy.response = {
                    type = proxy.MYSQLD_PACKET_ERR,
                    errmsg = out_msg
                }
                return proxy.PROXY_SEND_RESULT
            end

            return proxy.PROXY_SEND_QUERY

        end
    end
end


function connect_server() 
    local mpp = proxy.global.config.mpp

    -- Make sure we always serve as read-write queries.
    -- To service a read-only query, we switch the backends in read_query()

    if mpp.debug >= 1 then
        print("\n[connect_server] " .. proxy.connection.client.address)

        for i = 1, #proxy.backends do
            local s        = proxy.backends[i]
            print(string.format("  [%s] (%s) %s(%s)/%s(%s) connected_client = %s",
            i,s.address,
            mpp.levels.by_number.proxy_type[s.type],s.type,
            mpp.levels.by_number.proxy_state[s.state],s.state,
            s.connected_clients))
        end
    end

    -- -----------------------------------------
    -- load balancing
    --
    local servernode = load_balance("RW")
    --

    if servernode == 0 then
        proxy.connection.backend_ndx = 0
        if mpp.debug >= 1 then
            print("  [" .. 0 .. "] letting proxy choose a connection")
        end
    else
        proxy.connection.backend_ndx = servernode
        if mpp.debug >= 1 then
            print("  [" .. servernode .. "] choosing an initial connection")
        end
    end

    -- open a new connection 
end

