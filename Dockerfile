FROM rabbitmq:3.11-alpine

RUN set eux; \
    rabbitmq-plugins enable --offline rabbitmq_management; \
    rm -f /etc/rabbitmq/conf.d/management_agent.disable_metrics_collector.conf; \
    cp /plugins/rabbitmq_management-*/priv/www/cli/rabbitmqadmin /usr/local/bin/rabbitmqadmin; \
    [ -s /usr/local/bin/rabbitmqadmin ]; \
    chmod +x /usr/local/bin/rabbitmqadmin; \
    apk add --no-cache python3 curl; \
    curl -L https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/3.11.1/rabbitmq_delayed_message_exchange-3.11.1.ez > $RABBITMQ_HOME/plugins/rabbitmq_delayed_message_exchange-3.11.1.ez; \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange rabbitmq_consistent_hash_exchange rabbitmq_prometheus rabbitmq_shovel rabbitmq_shovel_management; \
    apk del curl; \
    rabbitmqadmin --version \

EXPOSE 15671 15672