FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
    iproute2 iptables tcpdump iputils-ping curl && \
    apt-get clean

# Script de inicialização para aplicar regras
COPY rules.sh /usr/local/bin/rules.sh
RUN chmod +x /usr/local/bin/rules.sh

CMD ["/usr/local/bin/rules.sh"]
