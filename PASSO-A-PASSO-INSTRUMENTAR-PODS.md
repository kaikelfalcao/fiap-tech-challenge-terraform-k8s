# Passo a passo: instrumentar os pods do projeto no New Relic

Este guia foi montado com base nos arquivos deste repositório:
- `instrumentation.yaml` (auto-instrumentacao Node.js)
- `newrelic-values-local.yaml` (bundle + operator habilitado)
- `eks.tf` (nome padrao do cluster: `<project>-<env>-eks`)

## 1) Confirmar contexto do cluster

```bash
kubectl config current-context
kubectl get nodes
```

Se estiver no EKS de dev, o nome esperado tende a ser `fiap-tc-dev-eks` (conforme `eks.tf` + `environments/dev.tfvars`).

## 2) Confirmar que o operator do New Relic esta instalado

```bash
kubectl get deploy -n newrelic
kubectl get pods -n newrelic
```

Voce deve ver um deployment/pod relacionado a `k8s-agents-operator` em `Running`.

## 3) Confirmar namespace da aplicacao

Seu `instrumentation.yaml` atual instrumenta apenas o namespace `tech-challenge`:

```yaml
namespaceLabelSelector:
  matchExpressions:
    - key: "kubernetes.io/metadata.name"
      operator: "In"
      values: ["tech-challenge"]
```

Valide se esse namespace existe:

```bash
kubectl get ns
```

Se sua app estiver em outro namespace (ex.: `default`), ajuste o `values` no `instrumentation.yaml` antes de aplicar.

## 4) Aplicar a configuracao de instrumentacao

```bash
kubectl apply -f instrumentation.yaml
kubectl get instrumentation -A
kubectl describe instrumentation newrelic-instrumentation -n newrelic
```

## 5) Reiniciar os deployments da aplicacao

A injecao normalmente acontece na criacao do pod. Por isso, reinicie os deployments no namespace da app.

Exemplo para namespace `tech-challenge`:

```bash
kubectl rollout restart deployment -n tech-challenge
kubectl get pods -n tech-challenge -w
```

## 6) Validar se os pods foram instrumentados

Escolha um pod da aplicacao e verifique init containers/variaveis:

```bash
kubectl get pods -n tech-challenge
kubectl get pod <POD_NAME> -n tech-challenge -o yaml | grep -n "newrelic\|initContainers\|NEW_RELIC"
```

Tambem confira logs do operator:

```bash
kubectl get deploy -n newrelic -l app.kubernetes.io/name=k8s-agents-operator -o name
kubectl logs -n newrelic <DEPLOYMENT_NAME_DO_OPERATOR> --tail=200
```

## 7) Gerar trafego na aplicacao

Para aparecer APM rapidamente, gere algumas requisicoes para os endpoints da app (via browser, Postman ou curl).

## 8) Validar no New Relic

No New Relic (`https://one.newrelic.com`):
1. Abra a conta correta.
2. Va em `APM & Services` e procure pelo servico Node.js.
3. Va em `Kubernetes` e confirme pods/nodes/eventos do cluster.

Tempo comum para aparecer dados novos: 2 a 10 minutos.

## Troubleshooting rapido

### Nao aparece nada no APM

```bash
kubectl logs -n tech-challenge <POD_NAME> --tail=200
kubectl logs -n newrelic <DEPLOYMENT_NAME_DO_OPERATOR> --tail=200
```

- Confirme `spec.agent.language: nodejs` no `instrumentation.yaml`.
- Confirme que os pods foram recriados apos aplicar a Instrumentation.
- Confirme que ha trafego real na aplicacao.

### Namespace nao bate

- Ajuste `namespaceLabelSelector` em `instrumentation.yaml` para o namespace real da app.
- Reaplique e reinicie os deployments.

### Operator nao encontrado

- Reinstale/atualize o bundle com `k8s-agents-operator.enabled=true`.

```bash
helm upgrade --install newrelic-bundle newrelic/nri-bundle \
  -f newrelic-values-local.yaml \
  --namespace newrelic \
  --create-namespace
```

## Checklist final

- [ ] Cluster correto selecionado no `kubectl`
- [ ] Operator do New Relic em `Running`
- [ ] Namespace da app bate com `instrumentation.yaml`
- [ ] `Instrumentation` aplicada com sucesso
- [ ] Deployments reiniciados
- [ ] Pods com sinais de injecao New Relic
- [ ] Dados aparecendo em `APM & Services` e `Kubernetes`

