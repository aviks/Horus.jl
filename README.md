# Horus

[![Build Status](https://github.com/aviks/Horus.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/aviks/Horus.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![version](https://juliahub.com/docs/General/Horus/0.1.1/version.svg)](https://juliahub.com/ui/Packages/General/Horus)
[![pkgeval](https://juliahub.com/docs/General/Horus/0.1.1/pkgeval.svg)](https://juliahub.com/ui/Packages/General/Horus)
[![deps](https://juliahub.com/docs/General/Horus/0.1.1/deps.svg)](https://juliahub.com/ui/Packages/General/Horus?t=2)
[![docs](https://img.shields.io/badge/Documentation-blue)](https://docs.juliahub.com/General/Horus/stable/)


Simple background jobs for Julia, backed by Redis. 

Horus.jl is a package for creating and running background jobs in Julia

There are many libraries in other languages that provide similar functionality, such as Sidekiq, Resque (both Ruby) and Celery (Python). Of these, Sidekiq is probably the closest in spirit to this library. 

Currently requires a [patch to Redis.jl](https://github.com/JuliaDatabases/Redis.jl/pull/110) to fix a bug. An upcoming new release of Redis.jl will fix this. 

---

🚨 Please read the [documentation](https://docs.juliahub.com/General/Horus/stable/) carefully before using this package, particularly the section that describes what the design guarantees are. 

--- 
Horus is the ancient Egyptian god of kingship, protection, healing and the sky. 
