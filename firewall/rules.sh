#!/bin/bash                                # Define o interpretador do script como Bash
set -e                                      # Faz o script abortar se qualquer comando retornar erro (exit != 0)

# Laboratório mínimo de firewall
# - net_a: 172.30.0.0/24 (fw=172.30.0.2, client=172.30.0.10)    # Rede do cliente
# - net_b: 172.31.0.0/24 (fw=172.31.0.2, server=172.31.0.10:8080) # Rede do servidor

# Limpar regras antigas                     
iptables -F                                 # Limpa todas as chains da tabela filter (INPUT/FORWARD/OUTPUT)
iptables -t nat -F                          # Limpa todas as chains da tabela nat (PREROUTING/POSTROUTING/OUTPUT)
iptables -t mangle -F                       # Limpa todas as chains da tabela mangle (marcação/ajustes avançados)


# Define a política padrão para cada chain                          
iptables -P INPUT DROP                      # Bloqueia por padrão pacotes destinados ao próprio firewall
iptables -P FORWARD DROP                    # Bloqueia por padrão o roteamento entre interfaces
iptables -P OUTPUT ACCEPT                   # Permite por padrão saídas originadas do firewall

# Habilitar roteamento IP no kernel, Verifica se o kernel está com ip_forward habilitado (setado via compose)
CUR=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)  # Lê o valor atual de ip_forward (1=on, 0=off)
[ "$CUR" = "1" ] || echo "Aviso: ip_forward=0 (defina sysctls no compose)"  # Alerta se ip_forward estiver desligado

# Descobrir interfaces de cada rede pelo IP do fw, Detecta os nomes das interfaces conectadas às redes
IF_A=$(ip -o -4 addr show | awk '/172.30.0.2\//{print $2}')     # Ex.: eth0 da net_a (IP 172.30.0.2)
IF_B=$(ip -o -4 addr show | awk '/172.31.0.2\//{print $2}')     # Ex.: eth1 da net_b (IP 172.31.0.2)
echo "Interfaces detectadas: IF_A=$IF_A IF_B=$IF_B"              # Loga os nomes detectados para depuração

# Regras essenciais de segurança
iptables -A INPUT -i lo -j ACCEPT               # Permite tráfego na interface de loopback (localhost)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT  # Permite respostas a conexões já estabelecidas
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT # Permite encaminhar respostas de conexões já estabelecidas

# ICMP (ping) ao firewall nas duas redes - Facilita diagnóstico permitindo ping ao IP do fw em cada rede
[ -n "$IF_A" ] && iptables -A INPUT -i "$IF_A" -p icmp -j ACCEPT   # Aceita ping vindo da rede net_a
[ -n "$IF_B" ] && iptables -A INPUT -i "$IF_B" -p icmp -j ACCEPT   # Aceita ping vindo da rede net_b

# Regras do laboratório HTTP - A partir daqui, regras funcionais do lab HTTP
# 1) DNAT: tudo que chegar ao fw na porta 8080 vai para o server 172.31.0.10:8080
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 172.31.0.10:8080  # Redireciona destino para o servidor

# 2) FORWARD: permitir tráfego para o server na porta 8080 (independente da interface de entrada)
iptables -A FORWARD -p tcp -d 172.31.0.10 --dport 8080 -j ACCEPT  # Libera encaminhamento até o servidor HTTP

# 3) SNAT/MASQUERADE: garantir retorno do server via fw - Garante que as respostas retornem via o firewall
[ -n "$IF_B" ] && iptables -t nat -A POSTROUTING -o "$IF_B" -p tcp -d 172.31.0.10 --dport 8080 -j MASQUERADE  # Altera origem para o IP do fw

echo "Firewall minimal aplicado. Acesse:"       # Mensagem informativa no log
echo "- Host -> http://localhost:8080 (via fw)" # Dica de acesso pelo host (porta publicada)
echo "- Client -> curl http://172.30.0.2:8080 (via fw)" # Dica de acesso a partir do container client

tail -f /dev/null                          # Mantém o container em execução (evita sair após aplicar regras)
