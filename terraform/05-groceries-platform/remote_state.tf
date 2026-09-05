# Reads 01-infrastructure's local state directly so registry_host doesn't
# have to be copy-pasted into terraform.tfvars by hand every deploy -- it's
# already an output there (outputs.tf), and both stacks run on the same
# host against local state.
data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "../01-infrastructure/terraform.tfstate"
  }
}
