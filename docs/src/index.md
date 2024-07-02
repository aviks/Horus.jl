```@meta
CurrentModule = Horus
```

# Horus

Simple background jobs for Julia, backed by Redis. 

Horus.jl is a package for creating background job, placing them on queues, and running them asynchronously. 

## Concepts

All state is held in Redis. There is no communication between Julia processes. 

* A  _client_ is any Julia process that submits a job to be run. This only needs a connection to a running Redis server. A client _enqueue_s a _job_, which then gets added to a queue on Redis. This could, for example, be a webserver that recieves user requests, as part of which it kicks off a background job. 

* A  _server_ or _runner_ is one or more dedicated Julia processes that _fetch_ jobs from the Redis queue, and _executes_ them. These processes typically would run an infinite loop, fetching and running jobs one after another. 

* Each job in enqueued on a *named* queue. The default queue name is "_default_". Each runner can be configured to fetch jobs from one or more of these named queues. This allows sophisticated configuration -- for example, fast  and slow jobs can be put on different queues, and processed on separate processes, so that a slow job does not block fast jobs. 

## Usage

A job is described using a custom struct, that subtypes `Horus.HorusJob`. Here we define an `EmailJob` that contains all the attributes necessary to send an email. 

```
module MyPackage
    using Horus

    struct EmailJob
        recipient::String
        subject::String
        message::String
    end
end
```

A client configuration is generated with a RedisConnection. This configuration object can then be used to enqueue a job. Here the `EmailJob` is enqueued on the `emails` queue. 

```
module MyPackage
    ...
    conn = RedisConnection(;host="x.x.x.x", port=6379)
    conf = HorusClientConfig(conn)

    Horus.enqueue(conf, EmailJob, "test@example.com", 
                                  "A Test Email",
                                  "The body of said email"
                        ; queue = "emails"
                    )
end
```

The code to perform the job (in this case, send an email) should be written in an override of 
the `Horus.execute` function for the specific job type. Here we define `execute` for our `EmailJob` type, which then uses the existing `SMTPClient` julia package to actually send an email. 

```
module MyPackage
    ...
    using SMTPClient
    function Horus.execute(job::EmailJob)
        opt = SendOptions()
        SMTPClient.send("smtps://your.server",
                [job.recipient], 
                "sender@example.com", IOBuffer(
                    "Date: Fri, 18 Oct 2024 21:44:29 +0100\r\n" *
                    "From: Sender <sender@example.com>\r\n" *
                    "To: $(job.recipient)\r\n" *
                    "Subject: $(job.subject)\r\n" *
                    "\r\n" *
                    "$(job.body)\r\n")
                )
    end

```

On the server/runner, ensure your julia environment contains all the necessary dependencies, and 
run a script that looks something like this: 

```
using MyPackage
using Horus
using Redis

conn = RedisConnection(;host="x.x.x.x", port=6379)
sconf = HorusServerConfig(conn, ["emails"])
start_runner(sconf) ## will block indefinitely. 

```


## Design & Guarantees

* The primary principle is simplicity, which will hopefully lead to robustness. However, the cost of that simplicity is that certain transactional behaviours cannot be guaranteed. We believe that is a worthwhile tradeoff that has been proven in many real world scenarios over the years. Read below for the details for what can and can't be guaranteed. 

* Runners can be simple, single threaded code. To increase throughput, runners can be scaled horizontally using multiple independent Julia processes, fetching from the same queue(s). 

* When multiple runners are be launched simultaneously against a queue, a job will *only* be made available to a single runner. A single job will never be fetched by two or more runners. 

* The execution of the job will be protected by a try/catch -- thus logic errors or bugs in the job execution code will usually not bring down a runner. 

* However, there is always the possibility of the runner process crashing when executing a job. The server will attempt to record this fact in Redis, but in the current implementation doesn't give any guarantees. Logs should make the information about crashed workers apparent, including which job it was running when it crashed. This behavior allows you to manually retry that job if needed. While this should be a rare occurance (and this architecture itself has been validated in similar libraries in other languages), in practice this means that production use of this package should typically provide for log aggregation and monitoring, as well as process monitoring. We hope this is a standard part of most production environments in this day and age.

## TODO 

* Retries and dead letter queues
* Admin web services
* Distinguish which julia objects can be serialized through this method, and which not (e.g. can the struct include closures?)
