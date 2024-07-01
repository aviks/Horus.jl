module Horus

using Redis
using JSON3
using StructTypes
using Dates

export HorusClientConfig, HorusServerConfig, HorusJob, start_runner
export enqueue, execute

abstract type HorusConfig; end

## Configuration for a Client
struct HorusClientConfig <: HorusConfig
   backend::Any
end

HorusClientConfig() = HorusClientConfig(RedisConnection())

## Configuration for a JobRunner
struct HorusServerConfig
   backend::Any
   queues::Vector{String}
   opts::Dict{Symbol, Any}
end

HorusServerConfig(backend=RedisConnection(), queues=["default"]; opts...) = HorusServerConfig(backend, queues, convert(Dict{Symbol, Any}, opts))

## All jobs should be subtypes of HorusJob
abstract type HorusJob; end

## Enqueue a job. Inputs are the type that represents that job, and the arguments
function enqueue(cfg::HorusClientConfig, typename::Type{T}, args...; queue::AbstractString="default", meta...) where T<: HorusJob
   data = convert(Dict{Symbol, Any}, meta)
   data[:typename] =  string(typename)
   data[:modulename] = string(parentmodule(typename))
   data[:args] =  args
   data[:tries] =  1
   data[:posted] =  now()
   data[:queue] = queue # This is redundant, but stored for later ease of use
   enqueue(cfg.backend, JSON3.write(data), queue)
end

## Enqueue a job given a json string representation. 
## This method is very low level, and does no validation that the json 
##     is syntactically or semantically correct. End users should not use this. 
function enqueue(conn::RedisConnection, payload::String, queue)
   lpush(conn, queue, payload)
end

function fetch(cfg::HorusServerConfig)
   fetch(cfg.backend, cfg.queues)
end

global TIMEOUT = 2

function fetch(conn::RedisConnection, queues)
   brpop(conn, queues, TIMEOUT)
end

function start_runner()
   cfg = HorusServerConfig(RedisConnection(), ["default"], Dict{Symbol, Any}())
   start_runner(cfg)
end

function start_runner(cfg)
   while true
      job = fetch_job(cfg)
      if job === nothing
         continue
      end
      run_job(cfg, job)
   end
end

## Fetches a job from Redis, and returns it as a dict
function fetch_job(cfg)
   jobfetch = fetch(cfg)
   if jobfetch === nothing
      return nothing
   end
   return JSON3.read(jobfetch[2])
end

function run_job(cfg, jobjson)
   modulename = getproperty(Main, Symbol(get(jobjson, "modulename", "Main")))
   jobtype = getproperty(modulename, Symbol(jobjson[:typename]))
   job = jobtype(jobjson.args...)
   @info "[Horus] Processing $job"
   try 
      execute(job)
   catch (ex) 
      @error "[Horus] Exception processing $job." exception=ex
   end
end

function execute end

end
