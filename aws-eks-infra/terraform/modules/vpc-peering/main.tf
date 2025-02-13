terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version              = ">= 5.0"
      configuration_aliases = [aws.requester, aws.accepter]
    }
  }
}

resource "aws_vpc_peering_connection" "peering" {
  provider    = aws.requester
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  peer_region = var.peer_region
  auto_accept = false

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-vpc-peering"
    }
  )
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  auto_accept              = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-vpc-peering-accepter"
    }
  )
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider                  = aws.requester
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.accepter.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.accepter.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}