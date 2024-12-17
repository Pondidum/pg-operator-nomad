# Postgres Operator (for Nomad)


## Goals

- simple usage
- automated backup and restore
- few configuration options
- credentials are written to vault
- vault integration with the `database/PostgreSQL` backend

## Use case

Nomad job which specifies some minimal metadata:

```c
job "docs" {
  meta {
    "database.enabled" = true
    "database.backup" = true
  }
}
```

Would cause a database to be created, and after creation configure Vault, and if there is a backup, restore that.

## Design

```mermaid
flowchart TD
	create_db --> schema_exists
	schema_exists --yes--> done
	schema_exists --no --> create_schema --> create_role --> configure_vault_role --> backup_enabled

	backup_enabled --no --> done
	backup_enabled --yes --> backup_exists
	backup_exists --no --> done
	backup_exists --yes --> restore_backup --> done
```

- start with a cli or script
- leave backup and restore for vNext
- create a reader, writer, deployer roles in vault


## Tasks

- [ ] docker-compose with Postgres, Vault, Grafana (OTEL)
- [ ] shell script to create a database
- [ ] expand script to configure vault
