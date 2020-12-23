output "Load Balancer DNS Name" {
  value       = aws_lb.front_end.dns_name
  description = "domain name LBS"
}