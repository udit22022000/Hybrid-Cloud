//provider

provider "aws"{
    region = "ap-south-1"
    profile = "udit"
}



//creating key

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
    vpc_id      = "vpc-18eaf770"

    ingress{
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    
    ingress{
        description = "http"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "allow_tcp"
  }
}

//creating S3 bucket

resource "aws_s3_bucket" "udit_s3" {
  bucket = "udit123442336436abcdef"
  acl    = "public-read"
  region = "ap-south-1"

  tags = {
    Name  = "My_bucket"
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
      Name  =  "My_bucket_upload"
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
      Name        = "Udit-Web-Distribution"
  }
  
  depends_on = [
    aws_s3_bucket_object.udit_s3_content
  ]
  
}

//creating aws-ec2 instance

resource "aws_instance" "udit_instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.udit_security.name]
  key_name = aws_key_pair.udit_key.key_name
 
  depends_on = [
    aws_security_group.udit_security,
    aws_key_pair.udit_key
  ]
  
  tags = {
    Name = "web-server"
  } 

}

//creating ebs volume...
resource "aws_ebs_volume" "udit_ebs" {
  availability_zone = aws_instance.udit_instance.availability_zone
  size              = 1
  tags = {
    Name = "task_ebs_vol"
  }
  
  depends_on = [
        aws_instance.udit_instance
    ]
}

//attaching ebs volume to the ec2 instance....

resource "aws_volume_attachment" "udit_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.udit_ebs.id
  instance_id = aws_instance.udit_instance.id
  force_detach = true
  
  depends_on = [
        aws_ebs_volume.udit_ebs
    ]
    
}

//configuration....

resource "null_resource" "udit_remote_config" {
  
  provisioner "remote-exec" {
  
    connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.udit_key_pair.private_key_pem
      host        = aws_instance.udit_instance.public_ip
    }
    
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo mkfs.ext4 /dev/sdh",
      "sudo mount /dev/sdh1 /var/www/html/",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/udit22022000/my_webpage.git /var/www/html/",
      "sudo sed -i 's@hacker.jpg@https://${aws_cloudfront_distribution.udit_cloudfront.domain_name}/hacker.jpg@g' /var/www/html/index.html"
    ]
    
    }
    depends_on = [
        aws_volume_attachment.udit_attach
    ]

}

output "web_server_ip" {
  value = aws_instance.udit_instance
}
