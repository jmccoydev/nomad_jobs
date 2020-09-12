job "vault" {
  datacenters = ["dc1"]
  group "vault" {
    constraint {
      attribute = "${node.unique.name}"
      value = "server-a-1"
    }
    count = 1
    task "vault" {
      driver = "raw_exec"
      config {
        command = "vault"
        args    = ["server", "-dev", "-dev-root-token-id=root", "-dev-listen-address=0.0.0.0:8200"]
      }
      artifact {
        source      = "https://releases.hashicorp.com/vault/1.5.3/vault_1.5.3_linux_amd64.zip"
      }
    }
  }
}
# Run group on node: server-a-1. Run in dc1.
# Download binary and extract.
# Run binary with arguments.