job "jenkins" {
  type = "service"
   datacenters = ["dc1"]
    update {
      stagger      = "30s"
        max_parallel = 1
    }
#  constraint {
#    attribute = "${driver.java.version}"
#    operator  = ">"
#    value     = "1.7.0"
#  }
  group "web" {
    count = 1
      # Size of the ephemeral storage for Jenkins. Consider that depending
      # on job count and size it could require larger storage.
      ephemeral_disk {
       migrate = true
       size    = "110"
       sticky  = true

     }
    task "frontend" {
      env {
        # Use ephemeral storage for Jenkins data.
        JENKINS_HOME = "/alloc/data"
#        JENKINS_SLAVE_AGENT_PORT = "${NOMAD_PORT_slave}"
      }
      driver = "java"
      config {
        jar_path    = "local/jenkins.war"
        jvm_options = ["-Xmx768m", "-Xms384m"]
        args        = ["--httpPort=${NOMAD_PORT_http}"]
      }
      artifact {
        # source = "http://ftp-chi.osuosl.org/pub/jenkins/war-stable/2.89.1/jenkins.war"
        source = "http://ftp-chi.osuosl.org/pub/jenkins/war/2.253/jenkins.war"
        options {
          # Checksum will change depending on the Jenkins Version.
          # checksum = "sha256:f9f363959042fce1615ada81ae812e08d79075218c398ed28e68e1302c4b272f"
          checksum = "sha256:d99c51292349af4934ab9769ba9ef2ed9ab9a8b118ff601aaabf1d5bf2a4e6a1"
        }
      }
      service {
        # This tells Consul to monitor the service on the port
        # labeled "http".
        port = "http"
        name = "jenkins"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.http2.rule=Path(`/jenkins`)",
          #"traefik.tags=service",
          #"traefik.http.routers.http.rule=PathPrefixStrip(`/jenkins`)",
          #"traefik.frontend.rule=PathPrefixStrip(/jenkins)",
        ]

        check {
          type     = "http"
          path     = "/login"
          interval = "10s"
          timeout  = "2s"
        }
    }

      resources {
          cpu    = 2000 # MHz
          memory = 768 # MB
          network {
            mbits = 100
            port "http" {
              static = 7090
            }
#            port "slave" {
#            }
          }
        }
      }
    }
}