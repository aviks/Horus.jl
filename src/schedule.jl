ZPOPBYSCORE_SCRIPT = """
local key, now = KEYS[1], ARGV[1]
local jobs = redis.call("zrange", key, "-inf", now, "byscore", "limit", 0, 1)
if jobs[1] then
  redis.call("zrem", key, jobs[1])
  return jobs[1]
end
"""

zpopbyscore_script_sha = nothing
scheduler_done = false
scheduled_sets = ["horus_retry", "horus_schedule"]

function enqueue_jobs(cfg::HorusServerConfig)
    try 
        for set in scheduled_sets
            while !scheduler_done
                job = zpopbyscore(cfg.backend, set, now().instant.periods.value)
                if job === nothing
                    break
                end
                enqueue(cfg.backend, JSON3.read(job)) # need to read the queue from the job, so need to parse it. 
            end
        end
    catch e 
         @error "Exception enqueuing jobs in scheduler" exception=(e, catch_backtrace())
    end
end

# Needs fixes in Redis.jl
# function zpopbyscore(conn, keys, argv)
#    @repeat 2 try
#         if lua_zpopbyscore_sha === nothing
#             global lua_zpopbyscore_sha == script_load(conn, ZPOPBYSCORE_SCRIPT)
#             @info "Loaded ZPOPBYSCORE to Redis"
#         end
#             evalsha(conn,lua_zpopbyscore_sha, 1, keys, argv )
#     catch e 
#            @retry if startswith(e.message, "NOSCRIPT")
#                 global lua_zpopbyscore_sha = nothing
#            end
#     end
# end 

function zpopbyscore(conn, keys, argv)
    evalscript(conn, ZPOPBYSCORE_SCRIPT, 1, vcat(keys, argv))
end

function enqueue_at(cfg::HorusClientConfig, typename::Type{T}, time::DateTime, args...; queue::AbstractString="horus_default", meta...) where T<: HorusJob
   data = convert(Dict{Symbol, Any}, meta)
   data[:typename] =  string(typename)
   data[:modulename] = string(parentmodule(typename))
   data[:args] =  args
   data[:tries] =  1
   data[:posted] =  now()
   data[:id] = incr(cfg.backend, "jobid")
   data[:queue] = queue
   enqueue_at(conn, data, "horus_schedule", time)
end

function enqueue_at(conn::RedisConnection, payload, queue::String, time::DateTime)
    enqueue_at(conn, JSON3.write(payload), queue, time.instant.periods.value)
end

function enqueue_at(conn::RedisConnection, payload::String, queue::String, time::Integer)
    zadd(conn, queue, time, payload)
end


function terminate_scheduler()
    global scheduler_done = true
end

POLL_INTERVAL = 5 #seconds
MAXTRIES = 20

function retry_job(cfg::HorusServerConfig, job, st, errmsg)
    tries = get(job, :tries, 0) + 1
    job =  copy(job) 
    job[:tries] = tries
    job[:errmsg] = errmsg
    job[:stacktrace] = repr("text/plain", st[1:min(end, 5)], context=:compact=>true)
    if tries > min(get(job, :maxtries, MAXTRIES), get(cfg.opts, :maxtries, MAXTRIES))
        lpush(cfg.backend, "horus_dlq", jobjson)
        @info "Sending job $(job[:id]) to Dead Letter Queue"
        return
    end 
    job[:queue] = get(job, :retry_queue, job[:queue]) #move job to a slower retry queue if configured 
    time = now()+Second(tries^4 * 5)
    enqueue_at(cfg.backend, job, "horus_retry", time)
end

function start_scheduler(cfg::HorusServerConfig)
    t = @task begin    
        while !scheduler_done
            @info "Running Scheduler at $(now())"
            enqueue_jobs(cfg)
            wait(Base.Timer(POLL_INTERVAL))
        end
        @info "Shutting down Scheduler"
    end
    t.sticky = false
    @info "Starting Scheduler"
    schedule(t)
    return t
end
