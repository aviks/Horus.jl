using Horus
using Test
using Redis

global x = 1
struct TestJob1 <:HorusJob
    a
end

function Horus.execute(t::TestJob1)
    global x = x + t.a
end

#This test assumes redis running on localhost
@testset "Horus.jl" begin
    #conn = RedisConnection(;host="172.23.164.254", port=6379)
    conn = RedisConnection(;host="127.0.0.1", port=6379)
    conf = Horus.HorusClientConfig(conn)

    Horus.enqueue(conf, TestJob1, 1)

    sconf = Horus.HorusServerConfig(conn)
    Horus.run_job(sconf, Horus.fetch_job(sconf))
    @test x == 2
end
