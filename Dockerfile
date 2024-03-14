FROM rabbitmq:3.13.0-management

RUN apt-get update; \
    apt-get install -y --no-install-recommends curl; \
    curl -L https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v3.13.0/rabbitmq_delayed_message_exchange-3.13.0.ez > $RABBITMQ_HOME/plugins/rabbitmq_delayed_message_exchange-3.13.0.ez; \
    rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange rabbitmq_consistent_hash_exchange rabbitmq_prometheus rabbitmq_shovel rabbitmq_shovel_management