job "hashicups" {
  multiregion {
    strategy {
      max_parallel = 1
      on_failure   = "fail_all"
    }
    region "west" {
      count = 3
      datacenters = ["dc1"]
    }
    region "east" {
      count = 1
      datacenters = ["east-1"]
    }
  }

  # Define Nomad Scheduler to be used (Service/Batch/System)
  type  = "service"

  # Each component is defined within it's own Group
  group "postgres" {
    count = 1

    # Host volume on which to store Postgres Data.  Nomad will confirm the client offers the same volume for placement.
    volume "pgdata" {
      type      = "host"
      read_only = false
      source    = "pgdata"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

    #Actual Postgres task using the Docker Driver
    task "postgres" {
      driver = "docker"

      volume_mount {
        volume      = "pgdata"
        destination = "/var/lib/postgresql/data"
        read_only   = false
        }

     # Postgres Docker image location and configuration
     config {
        image = "hashicorpdemoapp/product-api-db:v0.0.11"
        dns_servers = ["172.17.0.1"]
        network_mode = "host"
        port_map {
          db = 5432
        }
      }

      # Task relevant environment variables necessary
      env {
          POSTGRES_USER="root"
          POSTGRES_PASSWORD="password"
          POSTGRES_DB="products"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      # Host machine resources required
      resources {
        cpu = 100 #1000
        memory = 300 #1024
        network {
          port  "db"  {
            static = 5432
          }
        }
      }

      # Service definition to be sent to Consul
      service {
        name = "postgres"
        port = "db"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    } # end postgres task
  } # end postgres group

  # Products API component that interfaces with the Postgres database
  group "products-api" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "products-api" {
      driver = "docker"

      # Creation of the template file defining how the API will access the database
      template {
        destination   = "/secrets/db-creds"
        data = <<EOF
{
  "db_connection": "host=postgres.service.consul port=5432 user=root password=password dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
EOF
      }

      # Task relevant environment variables necessary
      env = {
        "CONFIG_FILE" = "/secrets/db-creds"
      }

      # Product-api Docker image location and configuration
      config {
        image = "hashicorpdemoapp/product-api:v0.0.11"
        dns_servers = ["172.17.0.1"]
        port_map {
          http_port = 9090
        }
      }

      # Host machine resources required
      resources {
        #cpu    = 500
        #memory = 1024
        network {
          #mbits = 10
          port  "http_port"  {
            static = 9090
          }
        }
      }

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "products-api-server"
        port = "http_port"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.products.entrypoints=products",
          "traefik.http.routers.products.rule=Path(`/`)",
        ]
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    } # end products-api task
  } # end products-api group

  # Public API component
  group "public-api" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    # Define update strategy for API component
    update {
      canary  = 1
    }

    task "public-api" {
      artifact {
        source = "https://github.com/hashicorp-demoapp/public-api/releases/download/v0.0.1/public-api"
      }
      driver = "raw_exec"

      # Task relevant environment variables necessary
      env = {
        BIND_ADDRESS = ":8080"
        PRODUCT_API_URI = "http://products-api-server.service.consul:9090"
      }

      # Comand to run the binary
      config {
        command = "public-api"
      }

      # Host machine resources required
      resources {
        #cpu    = 500
        #memory = 1024

        network {
          port "pub_api" {
            static = 8080
          }
        }
      }

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "public-api-server"
        port = "pub_api"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.public.entrypoints=public",
          "traefik.http.routers.public.rule=Path(`/`)",
        ]
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # Frontend component providing user access to the application

  group "frontend" {
    count = 0

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "server" {
      driver = "docker"

      # Task relevant environment variables necessary
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      # Frontend Docker image location and configuration
      config {
        image = "hashicorpdemoapp/frontend:v0.0.3"
        dns_servers = ["172.17.0.1"]
        volumes = [
          "local:/etc/nginx/conf.d",
        ]
      }

      # Creation of the NGINX configuration file
      template {
        data = <<EOF
resolver 172.17.0.1 valid=1s;
server {
    listen       80;
    server_name  localhost;
    set $upstream_endpoint public-api-server.service.consul;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    # Proxy pass the api location to save CORS
    # Use location exposed by Consul connect
    location /api {
        proxy_pass http://$upstream_endpoint:8080;
        # Need the next 4 lines. Else browser might think X-site.
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
        destination   = "local/default.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      # Host machine resources required
      resources {
        network {
          mbits = 10
          port  "http"{
            static = 80
          }
        }
      }

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "frontend"
        port = "http"

        tags = [
          # "traefik.enable=true",
          # "traefik.http.routers.frontend.rule=Path(`/frontend`)",
          "traefik.enable=true",
          "traefik.http.routers.frontend.entrypoints=frontend",
          "traefik.http.routers.frontend.rule=Path(`/`)",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
