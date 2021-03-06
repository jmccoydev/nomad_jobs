job "hashicups" {
  multiregion {
    strategy {
      max_parallel = 1
      on_failure   = "fail_all"
    }
    region "west" {
      # count       = 1 #optional
      datacenters = ["dc1"]
    }
    # region "east" {
    #   # count       = 1 #optional
    #   datacenters = ["east-1"]
    # }
  }

  type     = "service"
  group "postgres" {
    count = 1

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

    task "postgres" {
      driver = "docker"

      volume_mount {
        volume      = "pgdata"
        destination = "/var/lib/postgresql/data"
        read_only   = false
        }

     config {
        image = "hashicorpdemoapp/product-api-db:v0.0.11"
        dns_servers = ["172.17.0.1"]
        network_mode = "host"
        port_map {
          db = 5432
        }

      }
      env {
          POSTGRES_USER="root"
          POSTGRES_PASSWORD="password"
          POSTGRES_DB="products"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 100 #1000
        memory = 300 #1024
        network {
          #mbits = 10
          port  "db"  {
            static = 5432
          }
        }
      }

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
    }
  }

  group "products-api" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    update {
      canary       = 1
      max_parallel = 5
    }
    task "products-api" {
      driver = "docker"
      vault {
        policies = ["products-api"]
      }
      template {
        destination   = "/secrets/db-creds"
        data = <<EOF
{{ with secret "kv/db/postgres/product-db-creds" }}
{
  "db_connection": "host=postgres.service.consul port=5432 user={{ .Data.username }} password={{ .Data.password }} dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
{{ end }}
EOF
      }

      env = {
        "CONFIG_FILE" = "/secrets/db-creds"
      }
      config {
        image = "hashicorpdemoapp/product-api:v0.0.11"
        dns_servers = ["172.17.0.1"]
        port_map {
          http_port = 9090
        }
      }
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
      service {
        name = "products-api-server"
        port = "http_port"
        tags = [
          # "traefik.enable=true",
          # "traefik.http.routers.products.entrypoints=products",
          # "traefik.http.routers.products.rule=Path(`/`)",
        ]
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  group "public-api" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "public-api" {
      driver = "docker"

      env = {
        BIND_ADDRESS = ":8080"
        PRODUCT_API_URI = "http://products-api-server.service.consul:9090"
      }

      config {
        image = "hashicorpdemoapp/public-api:v0.0.1"
        dns_servers = ["172.17.0.1"]

        port_map {
          pub_api = 8080
        }
      }

      resources {
        #cpu    = 500
        #memory = 1024

        network {
          port "pub_api" {
            static = 8080
          }
        }
      }
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

  group "frontend" {
    count = 3

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      driver = "docker"

      config {
        image = "hashicorpdemoapp/frontend:v0.0.3"
        dns_servers = ["172.17.0.1"]
        volumes = [
          "local:/etc/nginx/conf.d",
        ]
      }

      template {
        data = <<EOF
server {
    listen       80;
    server_name  localhost;
    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;
    # proxy_http_version 1.1;
    # proxy_set_header Upgrade $http_upgrade;
    # proxy_set_header Connection "Upgrade";
    # proxy_set_header Host $host;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    # Proxy pass the api location to save CORS
    # Use location exposed by Consul connect
    location /api {
        proxy_pass http://public-api-server.service.consul:8080;
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

      resources {
        network {
          mbits = 10
          port  "http"{
            static = 80
          }
        }
      }

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