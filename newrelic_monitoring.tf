# ── New Relic Dashboard ───────────────────────────────────────────────────────
resource "newrelic_one_dashboard" "autoflow" {
  name        = "AutoFlow — Observabilidade"
  permissions = "public_read_only"

  # ── Página 1: Ordens de Serviço ──────────────────────────────────────────────
  page {
    name = "Ordens de Serviço"

    widget_line {
      title  = "Volume Diário de Ordens Abertas"
      row    = 1
      column = 1
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Ordens Abertas'
          FROM ServiceOrderEvent
          WHERE event = 'opened'
          SINCE 30 days ago
          TIMESERIES 1 day
        NRQL
      }
    }

    widget_billboard {
      title  = "Ordens Hoje"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Total'
          FROM ServiceOrderEvent
          WHERE event = 'opened'
          SINCE today
        NRQL
      }
    }

    widget_bar {
      title  = "Transições de Status (24h)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Transições'
          FROM ServiceOrderStatusChanged
          SINCE 24 hours ago
          FACET to
        NRQL
      }
    }

    widget_billboard {
      title  = "Tempo Médio de Finalização (horas)"
      row    = 4
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT average(durationMs) / 3600000 AS 'Horas'
          FROM ServiceOrderFinalized
          SINCE 7 days ago
        NRQL
      }
    }

    widget_pie {
      title  = "Budget: Aprovado vs Rejeitado"
      row    = 4
      column = 10
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*)
          FROM ServiceOrderBudgetApproved, ServiceOrderBudgetRejected
          SINCE 7 days ago
          FACET eventType()
        NRQL
      }
    }

    widget_line {
      title  = "Transições por Status ao Longo do Tempo"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Transições'
          FROM ServiceOrderStatusChanged
          SINCE 7 days ago
          FACET to
          TIMESERIES 1 hour
        NRQL
      }
    }
  }

  # ── Página 2: APIs & Performance ─────────────────────────────────────────────
  page {
    name = "APIs & Performance"

    widget_line {
      title  = "Latência HTTP — P50 / P95 (ms)"
      row    = 1
      column = 1
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT percentile(duration * 1000, 50, 95) AS 'ms'
          FROM Transaction
          WHERE appName = 'autoflow-tc'
          SINCE 1 hour ago
          TIMESERIES
        NRQL
      }
    }

    widget_billboard {
      title  = "Taxa de Erros HTTP (1h)"
      row    = 1
      column = 9
      width  = 4
      height = 3

      critical = 5
      warning  = 1

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT percentage(count(*), WHERE error IS true) AS '%'
          FROM Transaction
          WHERE appName = 'autoflow-tc'
          SINCE 1 hour ago
        NRQL
      }
    }

    widget_bar {
      title  = "Throughput por Endpoint (1h)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Requisições'
          FROM Transaction
          WHERE appName = 'autoflow-tc'
          SINCE 1 hour ago
          FACET request.uri
          LIMIT 10
        NRQL
      }
    }

    widget_table {
      title  = "Top Erros (24h)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Ocorrências', latest(errorMessage) AS 'Mensagem'
          FROM TransactionError
          WHERE appName = 'autoflow-tc'
          SINCE 24 hours ago
          FACET error.class
          LIMIT 10
        NRQL
      }
    }

    widget_line {
      title  = "Latência por Método HTTP (Custom)"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT average(newrelic.timeslice.value) * 1000 AS 'ms'
          FROM Metric
          WHERE metricTimesliceName LIKE 'Custom/API/Latency/%'
          AND appName = 'autoflow-tc'
          SINCE 1 hour ago
          FACET metricTimesliceName
          TIMESERIES
        NRQL
      }
    }
  }

  # ── Página 3: Kubernetes ─────────────────────────────────────────────────────
  page {
    name = "Kubernetes"

    widget_line {
      title  = "CPU Usage (Cores)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT average(cpuUsedCores) AS 'Used', average(cpuRequestedCores) AS 'Requested'
          FROM K8sContainerSample
          WHERE clusterName = 'fiap-tc-dev-eks'
          AND namespaceName = 'autoflow'
          SINCE 1 hour ago
          TIMESERIES
        NRQL
      }
    }

    widget_line {
      title  = "Memória (MB)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT average(memoryWorkingSetBytes) / 1e6 AS 'Working Set MB',
                 average(memoryRequestedBytes) / 1e6 AS 'Requested MB'
          FROM K8sContainerSample
          WHERE clusterName = 'fiap-tc-dev-eks'
          AND namespaceName = 'autoflow'
          SINCE 1 hour ago
          TIMESERIES
        NRQL
      }
    }

    widget_billboard {
      title  = "Pods Running"
      row    = 4
      column = 1
      width  = 4
      height = 3

      critical = 0
      warning  = 1

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT uniqueCount(podName) AS 'Running'
          FROM K8sPodSample
          WHERE clusterName = 'fiap-tc-dev-eks'
          AND namespaceName = 'autoflow'
          AND status = 'Running'
          SINCE 5 minutes ago
        NRQL
      }
    }

    widget_line {
      title  = "HPA — Réplicas"
      row    = 4
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT latest(currentReplicas) AS 'Current', latest(desiredReplicas) AS 'Desired'
          FROM K8sHpaSample
          WHERE clusterName = 'fiap-tc-dev-eks'
          AND namespaceName = 'autoflow'
          SINCE 1 hour ago
          TIMESERIES
        NRQL
      }
    }

    widget_table {
      title  = "Eventos K8s — Warnings"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT message, reason, involvedObject.name AS 'Object'
          FROM InfrastructureEvent
          WHERE clusterName = 'fiap-tc-dev-eks'
          AND category = 'Warning'
          AND namespaceName = 'autoflow'
          SINCE 1 hour ago
          LIMIT 20
        NRQL
      }
    }
  }

  # ── Página 4: Erros & Integrações ────────────────────────────────────────────
  page {
    name = "Erros & Integrações"

    widget_bar {
      title  = "Erros de Integração por Tipo (24h)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT sum(newrelic.timeslice.value) AS 'Erros'
          FROM Metric
          WHERE metricTimesliceName LIKE 'Custom/IntegrationError/%'
          AND appName = 'autoflow-tc'
          SINCE 24 hours ago
          FACET metricTimesliceName
        NRQL
      }
    }

    widget_line {
      title  = "Erros 5xx ao Longo do Tempo"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT count(*) AS 'Erros 5xx'
          FROM TransactionError
          WHERE appName = 'autoflow-tc'
          AND httpResponseCode >= 500
          SINCE 24 hours ago
          TIMESERIES 1 hour
        NRQL
      }
    }

    widget_table {
      title  = "Alertas de Estoque Abaixo do Mínimo"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT latest(itemCode) AS 'Código', latest(available) AS 'Disponível'
          FROM StockBelowMinimum
          SINCE 24 hours ago
          FACET itemId
          LIMIT 20
        NRQL
      }
    }

    widget_table {
      title  = "Logs de Erro Recentes"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = <<-NRQL
          SELECT message, requestId
          FROM Log
          WHERE level = 'error'
          AND entity.name = 'autoflow-tc'
          SINCE 1 hour ago
          LIMIT 20
        NRQL
      }
    }
  }
}

# ── Alert Policy ──────────────────────────────────────────────────────────────
resource "newrelic_alert_policy" "autoflow" {
  name                = "AutoFlow — Alertas"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

# ── Alert Conditions ──────────────────────────────────────────────────────────

resource "newrelic_nrql_alert_condition" "error_rate" {
  policy_id   = newrelic_alert_policy.autoflow.id
  name        = "Taxa de Erros Alta"
  type        = "static"
  enabled     = true
  description = "Dispara quando a taxa de erros HTTP superar 5% por 5 minutos"

  nrql {
    query = <<-NRQL
      SELECT percentage(count(*), WHERE error IS true)
      FROM Transaction
      WHERE appName = 'autoflow-tc'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

resource "newrelic_nrql_alert_condition" "api_latency" {
  policy_id   = newrelic_alert_policy.autoflow.id
  name        = "Latência de API Alta"
  type        = "static"
  enabled     = true
  description = "Dispara quando o P95 da latência superar 2s por 5 minutos"

  nrql {
    query = <<-NRQL
      SELECT percentile(duration * 1000, 95)
      FROM Transaction
      WHERE appName = 'autoflow-tc'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 2000
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 1000
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "last_value"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

resource "newrelic_nrql_alert_condition" "pod_not_running" {
  policy_id   = newrelic_alert_policy.autoflow.id
  name        = "Pod Fora do Ar"
  type        = "static"
  enabled     = true
  description = "Dispara quando algum pod do autoflow não estiver em Running"

  nrql {
    query = <<-NRQL
      SELECT uniqueCount(podName)
      FROM K8sPodSample
      WHERE clusterName = 'fiap-tc-dev-eks'
      AND namespaceName = 'autoflow'
      AND status != 'Running'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 120
    threshold_occurrences = "all"
  }

  fill_option        = "static"
  fill_value         = 0
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

resource "newrelic_nrql_alert_condition" "integration_errors" {
  policy_id   = newrelic_alert_policy.autoflow.id
  name        = "Erros de Integração"
  type        = "static"
  enabled     = true
  description = "Dispara quando houver erros em integrações externas"

  nrql {
    query = <<-NRQL
      SELECT sum(newrelic.timeslice.value)
      FROM Metric
      WHERE metricTimesliceName LIKE 'Custom/IntegrationError/%'
      AND appName = 'autoflow-tc'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "static"
  fill_value         = 0
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

resource "newrelic_nrql_alert_condition" "service_order_failures" {
  policy_id   = newrelic_alert_policy.autoflow.id
  name        = "Falha no Processamento de Ordens de Serviço"
  type        = "static"
  enabled     = true
  description = "Dispara quando erros em transações de ordens de serviço superam o threshold"

  nrql {
    query = <<-NRQL
      SELECT count(*)
      FROM TransactionError
      WHERE appName = 'autoflow-tc'
      AND transactionName LIKE '%ServiceOrder%'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "static"
  fill_value         = 0
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# ── Notificação por e-mail (opcional) ────────────────────────────────────────
resource "newrelic_notification_destination" "email" {
  count = var.newrelic_alert_email != "" ? 1 : 0

  name = "autoflow-email-alerts"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.newrelic_alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.newrelic_alert_email != "" ? 1 : 0

  name           = "autoflow-email-channel"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email[0].id
  product        = "IINT"

  property {
    key   = "subject"
    value = "AutoFlow — Alerta: {{issueTitle}}"
  }
}

resource "newrelic_workflow" "autoflow" {
  count = var.newrelic_alert_email != "" ? 1 : 0

  name                  = "autoflow-alert-workflow"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "autoflow-policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.autoflow.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}
