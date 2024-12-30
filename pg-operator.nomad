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
