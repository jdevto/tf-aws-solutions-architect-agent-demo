# =============================================================================
# SECURITY GROUP FOR APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

# =============================================================================
# TARGET GROUP
# =============================================================================

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-tg"
  port     = var.target_port
  protocol = var.target_protocol
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = var.health_check_protocol
    matcher             = var.health_check_matcher
    port                = "traffic-port"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tg"
  })
}

# =============================================================================
# TARGET GROUP ATTACHMENT
# =============================================================================

resource "aws_lb_target_group_attachment" "this" {
  count            = var.create_target_attachments ? length(var.target_instance_ids) : 0
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_ids[count.index]
  port             = var.target_port
}

# =============================================================================
# LISTENER
# =============================================================================

resource "aws_lb_listener" "http" {
  count             = var.enable_http_listener ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "https" {
  count             = var.enable_https_listener && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
