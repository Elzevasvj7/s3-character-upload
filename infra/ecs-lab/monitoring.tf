# 1. Topic de SNS para canalizar las alertas
resource "aws_sns_topic" "alerts" {
  name         = "${local.app_name}-alerts"
  display_name = "Lab Alerts"

  tags = {
    Project = "aws-sdk-s3-lab"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.app_name}-unhealthy-hosts-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # 1 minuto en segundos
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alerta si una o más tareas de ECS fallan el health check del ALB."

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  # ¡Detalle de Arquitectura crítico!
  # CloudWatch no usa el ARN completo para ALB, usa el "arn_suffix" (app/... y targetgroup/...)
  dimensions = {
    TargetGroup  = aws_lb_target_group.api.arn_suffix
    LoadBalancer = aws_lb.api.arn_suffix
  }

  tags = {
    Project = "aws-sdk-s3-lab"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}