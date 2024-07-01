using Horus
using Test
using Redis

global x = 1
struct T1 <:HorusJob
    a
end

function Horus.execute(t::T1)
    @show t.a
    global x = x + t.a
    error("there was an error")
end

#This test assumes redis running on localhost
@testset "Horus.jl" begin
    conn = RedisConnection(;host="172.23.164.254", port=6379)
    conf = Horus.HorusClientConfig(conn)

    Horus.enqueue(conf, T1, 1)

    sconf = Horus.HorusServerConfig(conn)
    Horus.run_job(sconf, Horus.fetch_job(sconf))
    @test x == 2
end
