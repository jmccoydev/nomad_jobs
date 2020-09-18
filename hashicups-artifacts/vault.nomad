job "vault" {
  datacenters = ["dc1"]
  group "vault" {
    constraint {
      attribute = "${node.unique.name}"
      value = "server-a-1"
    }
    count = 1
    network {
      port "vault" {
        static = 8200
      }
    }
    task "vault" {
      driver = "raw_exec"
      config {
        command = "vault"
        args    = ["server", "-dev", "-dev-root-token-id=root", "-dev-listen-address=0.0.0.0:8200"]
        # args    = ["server", "-config /etc/vault.d", "-dev-root-token-id=root", "-dev-listen-address=0.0.0.0:8200"]
      }
      artifact {
        source      = "https://releases.hashicorp.com/vault/1.5.3/vault_1.5.3_linux_amd64.zip"
      }
    } # end task
    service {
      name = "vault-primary"
      tags = ["vault-primary"]
      port = "vault"
      check {
        name     = "vault alive"
        type     = "http"
        path     = "/ui"
        interval = "10s"
        timeout  = "2s"
      }
    } # end service
    task "configure vault" {
      constraint {
        attribute = "${node.unique.name}"
        value = "server-a-2"
      }
      driver = "raw_exec"
#       template {
#         data = <<EOH
# set -v

# consul connect envoy \
#   -mesh-gateway -register \
#     -service "gateway" \
#       -address "$(private_ip):8700" \
#       -wan-address "$(public_ip):8700"  \
#       -admin-bind "127.0.0.1:19005"
# EOH
#         destination = "script.sh"
#         perms = "755"
#       } # end template

      config {
        command = "bash"
        # args    = ["script.sh"]
        args = ["/root/nomad_jobs/hashicups/vault.sh"]
      }
    }

  } # end group
}
# Run group on node: server-a-1. Run in dc1.
# Download binary and extract.
# Run binary with arguments.