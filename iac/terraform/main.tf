terraform {
  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

resource "virtualbox_vm" "db" {
  count  = 1
  name   = "db-vm"
  image  = "./virtualbox.box"
  cpus   = 1
  memory = "1024 mib"

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    host_interface = "VirtualBox Host-Only Ethernet Adapter"
  }

  user_data = file("${path.module}/user_data.yml")
}

resource "virtualbox_vm" "worker" {
  count  = 1
  name   = "worker-vm"
  image  = "./virtualbox.box"
  cpus   = 1
  memory = "1024 mib"

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    host_interface = "VirtualBox Host-Only Ethernet Adapter"
  }

  user_data = file("${path.module}/user_data.yml")
}

output "db_ip" {
  value = element(virtualbox_vm.db.*.network_adapter.0.ipv4_address, 1)
}

output "worker_ip" {
  value = element(virtualbox_vm.worker.*.network_adapter.0.ipv4_address, 1)
}