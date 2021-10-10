resource "oci_load_balancer" "lb" {
  compartment_id = var.compartment_ocid
  subnet_ids = [
    oci_core_subnet.tcb_subnet1.id,
  ]

  display_name = "lb-webservers"
  shape          = "flexible"
  reserved_ips {
    id = "${oci_core_public_ip.test_reserved_ip.id}"
  }  

shape_details {
      minimum_bandwidth_in_mbps = 10
      maximum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "lb-bes" {
  name             = "lb-bes"
  load_balancer_id = oci_load_balancer.lb.id
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

resource "oci_load_balancer_backend" "lb-be1" {
  load_balancer_id = oci_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes.name
  ip_address       = oci_core_instance.webserver1.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "lb-be2" {
  load_balancer_id = oci_load_balancer.lb.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes.name
  ip_address       = oci_core_instance.webserver2.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_listener" "lb-listener" {
  connection_configuration {
    backend_tcp_proxy_protocol_version = "0"
    idle_timeout_in_seconds = "60"
  }
  load_balancer_id         = oci_load_balancer.lb.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.lb-bes.name
  hostname_names           = []
  port                     = 80
  protocol                 = "HTTP"

}
