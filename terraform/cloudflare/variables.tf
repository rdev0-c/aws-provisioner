variable "dns_record_name" {
  description = "The subdomain or domain name to configure in Cloudflare"
  type        = string
}

variable "ip_address" {
  description = "Public IP address of the EC2 instance"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with DNS write access"
  type        = string
  sensitive   = true
}