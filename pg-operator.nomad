variable "pg_host" { type = string }
variable "vault_addr" { type = string }

job "pg-operator" {

  group "operators" {
    count = 1

    task "listener" {
      driver = "exec"

      artifact {
        source = "https://github.com/Pondidum/nomad-listener/releases/download/71465c0/nomad-listener"
      }

      config {
        command = "nomad-listener"
        args    = [ "--verbose" ]
      }

      env {
        NOMAD_ADDR = "http://localhost:4646"
        PGHOST = var.pg_host
        PGDATABASE = "postgres"
        VAULT_ADDR = var.vault_addr
        OTEL_EXPORTER_OTLP_ENDPOINT = "otlp://${attr.unique.network.ip-address}:4317"
        OTEL_EXPORTER_OTLP_INSECURE = true
      }

      vault {
        role = "pg-operator"
      }

      template {
        data = <<-EOF
        {{ with secret "database/creds/operator" }}
        PGUSER="{{ .Data.username }}"
        PGPASSWORD="{{ .Data.password }}"
        {{ end }}
        EOF
        destination = "secrets/pg.env"
        env = true
      }

      template {
        data = file("handlers/Job-JobRegistered")
        destination = "handlers/Job-JobRegistered"
        perms = "744"
      }

      template {
        data = file("create-db.sh")
        destination = "create-db.sh"
        perms = "744"
        left_delimiter = "[["
        right_delimiter = "]]"
      }
    }
  }
}
