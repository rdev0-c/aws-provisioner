resource "cloudflare_record" "dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.dns_record_name
  type    = "A"
  content = var.ip_address
  ttl     = 1
  proxied = true
}