provider "nomad" {
  address = "http://server-a-1:4646"
}

variable "tfc_agent_token" {
  default = ""
}

# data "template_file" "job" {
#   template = "${file("${path.module}/tfc-agent.nomad.tmpl")}"

#   vars = {
#     tfc_agent_token = var.tfc_agent_token
#   }
# }

# resource "nomad_job" "tfc-agent" {
#   jobspec = data.template_file.job.rendered
# }

# output "job" { value = data.template_file.job.rendered }

resource "nomad_job" "hashicups" {
  jobspec = file("${path.module}/hashicups-2.nomad")
}