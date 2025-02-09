output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.peering.id
}

output "vpc_peering_connection_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection.peering.accept_status
}

output "requester_vpc_id" {
  description = "ID of the requester VPC"
  value       = aws_vpc_peering_connection.peering.vpc_id
}

output "accepter_vpc_id" {
  description = "ID of the accepter VPC"
  value       = aws_vpc_peering_connection.peering.peer_vpc_id
}