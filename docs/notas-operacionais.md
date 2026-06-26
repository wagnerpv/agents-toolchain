# Notas operacionais — ambientes de agente

Lições de como operar nos ambientes (sandbox/CI) onde os agentes rodam. Não é toolchain, é
o **modo de uso** — registrado aqui porque é infra compartilhada por todos os projetos.

---

## Processos em background não sobrevivem entre chamadas de shell

**Sintoma:** você sobe um servidor com `nohup ... &` numa chamada de bash, ele loga "ouvindo na
porta", e na chamada de bash **seguinte** o `curl` recebe *connection refused* — o processo morreu.

**Causa:** cada invocação de ferramenta bash é uma sessão própria. Processos em background
ficam atrelados a essa sessão e são reapados quando ela termina. O `&` não os torna persistentes
entre chamadas separadas; só dentro da mesma chamada.

**O que NÃO funciona:**
```sh
# chamada 1:
nohup meu-servidor & ; sleep 5 ; curl localhost:8080/health   # OK aqui
# chamada 2 (separada):
curl localhost:8080/health   # connection refused — o servidor sumiu
```

**O que funciona — gerenciar o ciclo de vida DENTRO de uma única chamada:**

1. **Deixe o test runner subir e derrubar.** É o padrão certo para suítes E2E. No delfweb-engine,
   o `e2e/conftest.py` (pytest) sobe o engine em `pytest_sessionstart`, espera o `/health`, roda
   todos os testes e derruba em `pytest_sessionfinish`. Tudo numa invocação de `pytest`:
   ```sh
   # uma única chamada de bash:
   cd ~/projeto && pytest e2e/tests_py/ -q
   ```
   O servidor vive exatamente durante a suíte e nada vaza entre chamadas.

2. **Se precisar subir manualmente para inspecionar**, faça boot + uso + teardown na MESMA chamada:
   ```sh
   nohup meu-servidor > /tmp/srv.log 2>&1 &
   PID=$!
   sleep 8
   curl -s localhost:8080/health
   curl -s localhost:8080/m/rota | head -c 400   # inspeção
   kill $PID                                       # derruba ainda nesta chamada
   ```

3. **Serviços de sistema persistentes** (ex.: Firebird via `fbguard`) podem sobreviver mais tempo
   porque são daemons desacoplados — mas não conte com isso entre chamadas distantes; re-cheque a
   porta e re-suba se preciso. Estado efêmero (ex.: senha do SYSDBA na security db) pode resetar.

**Regra geral:** trate cada chamada de bash como efêmera. Qualquer processo que precise existir
"durante o trabalho" ou é gerenciado por um runner (pytest, o próprio teste), ou nasce e morre
dentro da mesma chamada. Nunca dependa de um background de uma chamada anterior estar vivo.
