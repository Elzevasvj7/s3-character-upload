# Subred privada de us-east-2a.
resource "aws_subnet" "private_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.48.0/20"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "aws-sdk-s3-lab-private-a"
  }
}

# Subred privada de us-east-2b.
resource "aws_subnet" "private_b" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.64.0/20"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false

  tags = {
    Name = "aws-sdk-s3-lab-private-b"
  }
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id

  tags = {
    Name = "aws-sdk-s3-lab-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_nat_gateway" "regional" {
  vpc_id            = data.aws_vpc.default.id
  availability_mode = "regional"
  connectivity_type = "public"

  tags = {
    Name = "aws-sdk-s3-lab-nat"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "aws-sdk-s3-lab-s3-endpoint"
  }
}