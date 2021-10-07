// Copyright (c) 2017, 2021, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0


variable "compartment_ocid" {}
variable "region" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {}
variable "ssh_public_key" {}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid = var.user_ocid
  fingerprint = var.fingerprint
  private_key = var.private_key
  region = var.region
}

variable "ad_region_mapping" {
  type = map(string)

  default = {
    us-phoenix-1 = 2
    us-ashburn-1 = 2
    sa-saopaulo-1 = 1
  }
}

variable "images" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.9-2020.10.26-0"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaacirjuulpw2vbdiogz3jtcw3cdd3u5iuangemxq5f5ajfox3aplxa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaabbg2rypwy5pwnzinrutzjbrs3r35vqzwhfjui7yibmydzl7qgn6a"
    sa-saopaulo-1   = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaudio63gdicxwujhfok7jdyewf6iwl6sgcaqlyk4fvttg3bw6gbpq"
  }
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = var.ad_region_mapping[var.region]
}

resource "oci_core_virtual_network" "tcb_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "tcbVCN"
  dns_label      = "tcbvcn"
}

resource "oci_core_subnet" "tcb_subnet" {
  cidr_block        = "10.1.20.0/24"
  display_name      = "tcbSubnet"
  dns_label         = "tcbsubnet"
  security_list_ids = [oci_core_security_list.tcb_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.tcb_vcn.id
  route_table_id    = oci_core_route_table.tcb_route_table.id
  dhcp_options_id   = oci_core_virtual_network.tcb_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "tcb_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "tcbIG"
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
}

resource "oci_core_route_table" "tcb_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
  display_name   = "tcbRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tcb_internet_gateway.id
  }
}

resource "oci_core_public_ip" "test_reserved_ip" {
  compartment_id = "${var.compartment_ocid}"
  lifetime       = "RESERVED"

  lifecycle {
    ignore_changes = [private_ip_id]
  }
}

resource "oci_core_security_list" "tcb_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
  display_name   = "tcbSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
}

resource "oci_core_instance" "webserver1" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserver1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tcb_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "webserver1"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(var.user-data)
  }
  
  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

}

resource "oci_core_instance" "webserver2" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserver2"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tcb_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "webserver2"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(var.user-data)
  }
  
  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }
}

variable "user-data" {
  default = <<EOF
#!/bin/bash -x
echo '################### webserver userdata begins #####################'
# echo '########## yum update all ###############'
echo '########## basic webserver ##############'
yum install -y httpd
systemctl enable  httpd.service
systemctl start  httpd.service
firewall-offline-cmd --add-service=http
systemctl enable  firewalld
systemctl restart  firewalld
cd /var/www/html/
wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/u8j40_AS-7pRypC5boQT24w5QFPDTy-0j27BWBOfmsxbERTiuDtJQBIqfcsOH81F/n/idqfa2z2mift/b/bootcamp-oci/o/oci-f-handson-modulo-compute-website-files.zip
unzip oci-f-handson-modulo-compute-website-files.zip
chown -R apache:apache /var/www/html
echo '################### webserver userdata ends #######################'
EOF

}

/* Load Balancer */

resource "oci_load_balancer" "lb1" {
  shape          = "10Mbps"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.tcb_subnet.id,
  ]

  display_name               = "lb1"
  is_private                 = true
 # network_security_group_ids = [oci_core_network_security_group.test_network_security_group.id]
}

resource "oci_load_balancer_backend_set" "lb-bes1" {
  name             = "lb-bes1"
  load_balancer_id = oci_load_balancer.lb1.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }

  session_persistence_configuration {
    cookie_name      = "lb-session1"
    disable_fallback = true
  }
}

resource "oci_load_balancer_backend_set" "lb-bes2" {
  name             = "lb-bes2"
  load_balancer_id = oci_load_balancer.lb1.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }

  lb_cookie_session_persistence_configuration {
    cookie_name        = "example_cookie"
    domain             = "example.oracle.com"
    is_http_only       = false
    is_secure          = false
    max_age_in_seconds = 10
    path               = "/example"
    disable_fallback   = true
  }
}

#resource "oci_core_network_security_group" "test_network_security_group" {
  #Required
#  compartment_id = var.compartment_ocid
#  vcn_id         = oci_core_vcn.tcb_vcn.id
#}

output "lb_private_ip" {
  value = [oci_load_balancer.lb1.ip_address_details]
}
