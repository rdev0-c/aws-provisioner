output "dns_record" {
  value = cloudflare_record.dns.hostname
}