terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "default" {
  name = "simple-inventory"
  type = "dir"
  path = "/tmp/simple-inventory-pool"
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-base.img"
  pool   = libvirt_pool.default.name
  source = var.base_image
  format = "qcow2"
}

resource "libvirt_volume" "worker" {
  name           = "worker.img"
  pool           = libvirt_pool.default.name
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
  size           = 10737418240 # 10GB
}

resource "libvirt_volume" "db" {
  name           = "db.img"
  pool           = libvirt_pool.default.name
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
  size           = 10737418240 # 10GB
}

resource "libvirt_network" "inventory_net" {
  name      = "inventory-net"
  mode      = "nat"
  addresses = ["192.168.100.0/24"]
  dhcp { enabled = true }
  dns  { enabled = true }
}

resource "libvirt_cloudinit_disk" "worker_init" {
  name      = "worker-init.iso"
  pool      = libvirt_pool.default.name
  user_data = file("${path.module}/cloud-init-worker.yml")
}

resource "libvirt_cloudinit_disk" "db_init" {
  name      = "db-init.iso"
  pool      = libvirt_pool.default.name
  user_data = file("${path.module}/cloud-init-db.yml")
}

resource "libvirt_domain" "worker" {
  name   = "worker"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.worker_init.id

  network_interface {
    network_id     = libvirt_network.inventory_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

resource "libvirt_domain" "db" {
  name   = "db"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.db_init.id

  network_interface {
    network_id     = libvirt_network.inventory_net.id
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

output "worker_ip" {
  value = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  value = libvirt_domain.db.network_interface[0].addresses[0]
}