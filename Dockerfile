FROM rabbitmq:4.3.1-management

RUN apt-get update; \
    apt-get install -y --no-install-recommends curl unzip; \
    curl -L -o /tmp/rabbitmq_delayed_message_exchange.zip https://github.com/cloudamqp/rabbitmq-delayed-message-exchange/releases/download/v4.3.1/rabbitmq_delayed_message_exchange-4.3.1-erlang-26.zip && \
    unzip -o /tmp/rabbitmq_delayed_message_exchange.zip -d "$RABBITMQ_HOME/plugins" && \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange rabbitmq_consistent_hash_exchange rabbitmq_prometheus rabbitmq_shovel rabbitmq_shovel_management