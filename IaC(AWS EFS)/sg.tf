
//Provider
provider "aws"{
    region = "ap-south-1"
    profile = "udit"
}

//Key creation
resource "tls_private_key" "udit_key_pair"{
    algorithm = "RSA"
  }
 
resource "aws_key_pair" "udit_key"{
    key_name   = "udit33"
    public_key = tls_private_key.udit_key_pair.public_key_openssh
    
    depends_on = [
        tls_private_key.udit_key_pair
    ]
}

//creating security group
resource "aws_security_group" "udit_security" {
  name        = "udit_security"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "udit_security"
  }
}

//creating instance
resource "aws_instance" "udit_ec2" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name = aws_key_pair.udit_key.key_name
  vpc_security_group_ids = [aws_security_group.udit_security.id]

  connection{
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.udit_key_pair.private_key_pem
    host = aws_instance.udit_ec2.public_ip
  }

  provisioner "remote-exec" {
    inline = [
        "sudo yum install httpd php amazon-efs-utils git -y",
        "sudo service httpd start",
        "sudo chkconfig httpd on"
        ]
  }
  tags = {
    Name = "udit_ec2"
  }
}


//creating S3 bucket

resource "aws_s3_bucket" "udit_s3" {
  bucket = "udit123442336436710abc"
  acl    = "public-read"

  tags = {
    Name  = "udit_s3"
  }
}

//adding static content to the bucket....

resource "aws_s3_bucket_object" "udit_s3_content" {
  bucket = aws_s3_bucket.udit_s3.bucket
  key    = "hacker.jpg"
  source = "hacker.jpg"
  acl = "public-read"
  content_type = "image/jpg"
  
  depends_on = [
    aws_s3_bucket.udit_s3
  ]
  
  tags = {
      Name  =  "udit_s3_content"
}
}


//creating cloud-front

resource "aws_cloudfront_distribution" "udit_cloudfront" {

  origin {
    domain_name = aws_s3_bucket.udit_s3.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.udit_s3.id
    
    custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }

   }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Udit S3 Web Distribution"


  default_cache_behavior {
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = aws_s3_bucket.udit_s3.id
      forwarded_values {
          query_string = false

          cookies {
            forward = "none"
          }
        }
        
        
       viewer_protocol_policy = "allow-all"
       min_ttl                = 0
       default_ttl            = 3600
       max_ttl                = 86400
  }
  
  restrictions {
      geo_restriction {
          restriction_type = "none"
        }
    }
 
  viewer_certificate {
      cloudfront_default_certificate = true
   }

  tags = {
      Name  = "Udit-Web-Distribution"
  }
}


//creating EFS

resource "aws_efs_file_system" "udit_efs" {
  creation_token = "my-efs"

  tags = {
    Name = "udit_efs"
  }
}

//mounting efs..

resource "null_resource" "mount_efs" {

    connection{
        type = "ssh"
        user = "ec2-user"
        private_key = tls_private_key.udit_key_pair.private_key_pem
        host = aws_instance.udit_ec2.public_ip
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mount -t efs ${aws_efs_file_system.udit_efs.id}:/ /var/www/html",
            "sudo echo ${aws_efs_file_system.udit_efs.id}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
            "sudo rm -rf /var/www/html/*",
            "sudo git clone https://github.com/udit22022000/my_webpage.git /var/www/html/",
            "sudo sed -i 's@hacker.jpg@https://${aws_cloudfront_distribution.udit_cloudfront.domain_name}/hacker.jpg@g' /var/www/html/index.html"
        ]
    
    }
}



