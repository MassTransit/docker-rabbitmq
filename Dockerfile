FROM rabbitmq:3.8.9-management-alpine

ADD https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v3.8.0/rabbitmq_delayed_message_exchange-3.8.0.ez $RABBITMQ_HOME/plugins/

RUN rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange rabbitmq_consistent_hash_exchange rabbitmq_prometheus
