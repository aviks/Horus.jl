using Horus
using Test
using Redis
using JSON3

global x = 1
struct TestJob1 <:HorusJob
    a
end

function Horus.execute(t::TestJob1)
    global x = x + t.a
end

#This test assumes redis running on localhost
@testset "Horus.jl" begin
    redishost = "localhost"
    redishost = "172.23.164.254"
    conf = Horus.HorusClientConfig(;host=redishost, port=6379)

    Horus.enqueue(conf, TestJob1, 1)

    sconf = Horus.HorusServerConfig(;host=redishost, port=6379)
    redisjob = Horus.fetch(sconf)
    job = JSON3.read(redisjob[2])
    Horus.run_job(sconf, job)
    @test x == 2
end
