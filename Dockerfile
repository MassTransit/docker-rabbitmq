FROM rabbitmq:3.10.5-management-alpine

RUN apk add --no-cache curl && \
    curl -L https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/3.10.2/rabbitmq_delayed_message_exchange-3.10.2.ez > $RABBITMQ_HOME/plugins/rabbitmq_delayed_message_exchange-3.10.2.ez && \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange rabbitmq_consistent_hash_exchange rabbitmq_prometheus rabbitmq_shovel rabbitmq_shovel_management && \
    apk del curl
