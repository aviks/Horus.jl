module Horus

using Redis
using JSON3
using StructTypes
using Dates

export HorusClientConfig, HorusServerConfig, HorusJob, start_runner
export enqueue, execute
using Random

abstract type HorusConfig; end

"""
Configuration for a Client
"""
struct HorusClientConfig <: HorusConfig
   backend::Any
end

HorusClientConfig() = HorusClientConfig(RedisConnection())

"""
Configuration for a Sever/JobRunner
"""
struct HorusServerConfig
   backend::Any
   queues::Vector{String}
   opts::Dict{Symbol, Any}
end

HorusServerConfig(backend=RedisConnection(), queues=["horus_default"]; opts...) = HorusServerConfig(backend, queues, convert(Dict{Symbol, Any}, opts))

"""
All jobs should be subtypes of HorusJob
"""
abstract type HorusJob; end

"""

`enqueue(cfg::HorusClientConfig, typename::Type{T}, args...; queue::AbstractString="default", meta...) where T<: HorusJob`

Enqueue a job. Inputs are the type that represents that job, and the arguments
"""
function enqueue(cfg::HorusClientConfig, typename::Type{T}, args...; queue::AbstractString="horus_default", meta...) where T<: HorusJob
   data = convert(Dict{Symbol, Any}, meta)
   data[:typename] =  string(typename)
   data[:modulename] = string(parentmodule(typename))
   data[:args] =  args
   data[:tries] =  1
   data[:posted] =  now()
   data[:queue] = queue # This is redundant, but stored for later ease of use
   enqueue(cfg.backend, JSON3.write(data), queue)
end

"""
   `enqueue(conn::RedisConnection, payload)`

Enqueue a job given a json object representation. 
`payload` is converted to a string using `JSON3.write`, and queue is picked from the payload itself. 

This method is low level, and does not validate that the payload is semantically correct. Use with care. 
"""
function enqueue(conn::RedisConnection, payload)
   enqueue(cfg.backend, JSON3.write(payload), payload[:queue])
end

"""
   `enqueue(conn::RedisConnection, payload::String, queue)`

Enqueue a job given a json string representation. 

This method is very low level, and does not validate that the json is syntactically or 
semantically correct. End users should not use this. 
"""
function enqueue(conn::RedisConnection, payload::String, queue)
   lpush(conn, queue, payload)
end

"""
`fetch(cfg::HorusServerConfig)`

Fetches a job from Redis using the connection and queues from the supplied config. 
Uses brpop to fetch from the queue, and returns the redis result. 

Since `brpop` searches the queues in the order they are passed in, 
the queues are shuffled for each call to prevent exhaustion.  

If all the queues are empty, this function will block for TIMEOUT seconds
"""
function fetch(cfg::HorusServerConfig)
   fetch(cfg.backend, shuffle(cfg.queues))
end

global TIMEOUT = 2

function fetch(conn::RedisConnection, queues)
   brpop(conn, queues, TIMEOUT)
end

"""
`start_runner()``

Start a runner process, with a default RedisConnection talking to localhost
"""
function start_runner()
   cfg = HorusServerConfig(RedisConnection(), ["default"], Dict{Symbol, Any}())
   start_runner(cfg)
end

"""
`start_runner(cfg)`

Start a runner process, and block indefinitely
"""
function start_runner(cfg)
   while true
      redisjob = fetch(cfg)
      if redisjob === nothing
         continue
      end
      job = JSON3.read(redisjob[2])
      run_job(cfg, job)
   end
end

"""
`run_job(cfg::HorusServerConfig, jobjson::String)`

Run a job, given a job definiton as a json object
"""
function run_job(cfg, jobjson)
   modulename = getproperty(Main, Symbol(get(jobjson, "modulename", "Main")))
   jobtype = getproperty(modulename, Symbol(jobjson[:typename]))
   job = jobtype(jobjson.args...)
   @info "[Horus] Processing $job"
   try 
      execute(job)
   catch (ex)
      # Ensure that the log has the location of where the exception was thrown, not this place
      bt = catch_backtrace()
      st = stacktrace(bt)
      line = st[1].line
      file = string(st[1].file) 
      @error "[Horus] Exception processing $job." exception=ex _line=line _file=file
   end
end

function execute end

end
