# Firewall Lab (Minimal)

Laboratório mínimo para estudar regras de firewall (iptables) entre duas redes Docker.

## Arquitetura

- Redes
  - net_a: 172.30.0.0/24 (fw=172.30.0.2, client=172.30.0.10)
  - net_b: 172.31.0.0/24 (fw=172.31.0.2, server=172.31.0.10)
- Serviços
  - fw: container Debian com iptables, roteando net_a <-> net_b
  - server: HTTP simples em :8080 (Python)
  - client: imagem curl para testes

Veja também `img/arquitetura.png`.

## Subir o lab

```bash
docker compose down -v
docker compose up -d --build
```

## Testes rápidos

- Do host (porta publicada):

```bash
curl -I http://localhost:8080
```

- Do client (via fw):

```bash
docker exec -it client sh -lc 'curl -I http://172.30.0.2:8080'
```

- Inspecionar regras e rotas no fw:

```bash
docker exec -it fw bash -lc 'iptables -t nat -S; echo; iptables -S; echo; ip route'
```

## O que observar

- Pacotes entrando por uma interface e saindo por outra (FORWARD)
- DNAT no PREROUTING redirecionando :8080 para o server
- MASQUERADE garantindo o retorno via fw

## Ajustes

- Para liberar/fechar portas, edite `firewall/rules.sh`
- Para mudar sub-redes, edite `docker-compose.yml`
