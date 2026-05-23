variable "base_image" {
  description = "Path to Ubuntu cloud image"
  default     = "/home/artem/jammy-server-cloudimg-amd64.img"
}

variable "ansible_public_key" {
  description = "SSH public key for ansible user"
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBf+v5WQG7y/iA0umP346ts0YmriFbKG3FnkyW2r0B2 artem@LAPTOP-PLRK786C"
}
