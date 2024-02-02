# postgres-replication

This repo is an example of how to do replication between two postgres databases.

Launch using the following command:
```bash
docker compose up --build -d
```

Connect to primary:
```bash
docker exec -it pg-primary psql -U postgres
```

Insert a row into the primary:
```sql
INSERT INTO my_table VALUES(1, 'my data 1'); 
```

Connect to replica:
```bash
docker exec -it pg-replica psql -U postgres
```

Confirm that the row was replicated:
```sql
SELECT * FROM my_table;
```

## Misc

View information about the publication from the primary container.

```sql
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;
SELECT * FROM pg_replication_slots;
```


Postgres uses host based authentication to allow connections from subscribers.  It will work without changes when running on the local machine.  However, in a more complex deployment environment, it might be necessary to list the replica in the host based authentication file on the primary container.

```bash
nano /var/lib/postgresql/data/pg_hba.conf
```

The publication can be modified to add a new table.

```sql
ALTER PUBLICATION my_publication ADD TABLE new_table_name;
```
