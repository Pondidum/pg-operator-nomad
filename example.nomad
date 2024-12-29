
job "example" {
  datacenters = ["*"]

  meta = {
    "database.enabled" = true
  }

  group "servers" {
    count = 1

    network {
      port "www" {
        to = 8001
      }
    }


    task "web" {
      driver = "docker"

      config {
        image   = "busybox:1"
        command = "httpd"
        args    = ["-v", "-f", "-p", "${NOMAD_PORT_www}", "-h", "/local"]
        ports   = ["www"]
      }

      template {
        data        = <<-EOF
                      <h1>Hello, Nomad!</h1>
                      EOF
        destination = "local/index.html"
      }

      template {
        data = <<-EOF
                {{ with secret "database/creds/example-reader" }}
                <p>username: {{ .Data.username }}</p>
                <p>password: {{ .Data.password | toJSON }}</p>
                {{ end }}
               EOF
        destination = "local/config.html" 
      }

      vault {}


      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
