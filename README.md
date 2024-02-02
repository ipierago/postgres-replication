# zen-svc-poc

# transactional outbox pattern

when the backend finished processing a job, it creates an entry in the "transactional outbox" table as part of the job's transaction.  the outbox is replicated to the microservice.  the entry contains everything the microservice need to process/finalize the job. this is usually nothing more than a correlation id. the microservice should already have all the data it needs (think about 2PC pattern for currency spending - there is a reserved amount that needs to be burned/reclaimed).  the entry contains success/failure for the backend (orchestrator/conductor).

the outbox entry has a status field that is updated by the microservice. the microservice uses this status field to track if the update has been queued and if it has been successfully processed.  (yes, it updates a row after having it replicated to it from the primary, but that's ok because it is changes that are replicated. it isn't keeping databases identical, only makes changes).

when processing an update, the microservice modifies the outbox entry as part of the transaction

failure possibility is that the update is queued, but the outbox row is not updated.  this will cause the update to be queued multiple times.
the fix to this is to guarantee that it is ok for a message to be queued multiple times.
we can do this either by writing the code so that multiple operations have no additional affect (harder), or updating the outbox row once the update has been processed.
so, the outbox row has a status column with possible values "new", "queued", "finished"
need a heartbeat function that is called periodically to process any "new". in addition, can have trigger based processing of "new" for faster processing.  however, because triggered handler can fail, a periodically called function is a requirement. so, might as well start there.
only doing trigger based processing (queuing) of updates is not good enough because the handler might fail.  must have periodically called function as backup. trigger based processing is an optimization and something done in addition.


add a message queue for load balancing and retries
BullMQ does all this and can quarantee no correlation id is schedule more than once

there is a piece of code that watches for updates and then schedules in bullmq
there should be one instance of this per replciated database running (exactly)
this doesn't load balance well, because multiple concurrent handlers would tend to block one another. sharding is requried.
don't bother load balancing yet

build one service that can be deployed in multiple ways. standard polling of outbox, writing to replica database and submit to bullmq.

don't need to load balance in first implementation because applying changes should be very simple
the case where a reservation is successful should require almost no processing. goal is to make that path a no-op.



outbox pattern vs only message queue with acknowlegements
message queue does processing on-demand. this will typically mean changes are processed quicker (without a delay).
message queue also has built-in retries.
message queue allows better load balancing.
message queue has a critical point of failure - the queue of the update. queuing the update could fail and the update would be lost.  fixing this requires monitoring the updates for ones that did not get queued - so we are back to the outbox pattern.




Build and run primary:
```bash
docker build -f Dockerfile-pg-primary -t pg-primary .
docker run --name pg-primary -e POSTGRES_PASSWORD=password -d pg-primary
```

Build and run replica:
```bash
docker build -f Dockerfile-pg-replica -t pg-replica .
docker run --name pg-replica -e POSTGRES_PASSWORD=password -d pg-replica
```



useful commands:
```bash
docker run --name pg_primary -e POSTGRES_PASSWORD=password -d -p 5432:5432 postgres:latest
docker run --name pg_replica -e POSTGRES_PASSWORD=password -d -p 5433:5432 postgres:latest
docker exec -it pg_primary bash
apt-get update && apt-get install nano -y
nano /var/lib/postgresql/data/postgresql.conf
nano /var/lib/postgresql/data/pg_hba.conf
docker restart pg_primary
docker exec -it pg_primary psql -U postgres
```

useful sql:
```sql
CREATE PUBLICATION my_publication FOR ALL TABLES;
CREATE SUBSCRIPTION my_subscription CONNECTION 'host=primary_ip port=5432 user=postgres password=your_password dbname=postgres' PUBLICATION my_publication;
ALTER PUBLICATION my_publication ADD TABLE new_table_name;
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables WHERE pubname = 'your_publication_name';
SELECT * FROM pg_replication_slots WHERE slot_name = 'your_slot_name';
```

sql for primary:
```sql
create table table1(x int primary key, y int); 
insert into table1 values(10, 11);  
create publication my_publication for table table1;   
```

sql to client:
```sql
create table table1(x int primary key, y int); 
CREATE SUBSCRIPTION my_subscription 
CONNECTION 'host=localhost port=5432 dbname=postgres' PUBLICATION my_publication;
```


```bash
$ docker run --name pg_primary -e POSTGRES_PASSWORD=password -d -p 5432:5432 postgres:latest
cb302cb229792dc8635845a033da8a4e66d0445284635afa4c24502236b25f1d
$ docker run --name pg_replica -e POSTGRES_PASSWORD=password -d -p 5433:5432 postgres:latest
939b8d878b88c0ee14306415375709f543fa3a93bc28df11097d8e78c16921e0
$ docker ps
CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS                    NAMES
939b8d878b88   postgres:latest   "docker-entrypoint.s…"   5 minutes ago   Up 5 minutes   0.0.0.0:5433->5432/tcp   pg_replica
cb302cb22979   postgres:latest   "docker-entrypoint.s…"   6 minutes ago   Up 6 minutes   0.0.0.0:5432->5432/tcp   pg_primary
707ffacd4a9f   ea299dd31352      "/usr/bin/dumb-init …"   30 hours ago    Up 30 hours                             k8s_controller_ingress-nginx-controller-9d9dcf876-stj6h_ingress-nginx_51fd6547-7111-4435-ab9b-617d94ddadc9_116
$ docker inspect pg_replica | grep "\"IPAddress\""
            "IPAddress": "172.17.0.3",
                    "IPAddress": "172.17.0.3",
$ docker inspect pg_primary | grep "\"IPAddress\""
            "IPAddress": "172.17.0.2",
                    "IPAddress": "172.17.0.2",
```
