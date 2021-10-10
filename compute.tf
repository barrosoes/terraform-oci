resource "oci_core_instance" "webserver1" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserver1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tcb_subnet1.id
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
    subnet_id        = oci_core_subnet.tcb_subnet2.id
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

