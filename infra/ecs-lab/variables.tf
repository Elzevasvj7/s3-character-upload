variable "alb_allowed_cidr" {
  description = "CIDR autorizado para acceder al ALB por HTTP. 0.0.0.0/0 permite cualquier IP."
  type        = string
}
variable "alert_email" {
  description = "Correo electrónico para recibir alertas de CloudWatch."
  type        = string
}