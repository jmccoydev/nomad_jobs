job "vault" {
    datacenters = ["dc1"]
    group "vault" {
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