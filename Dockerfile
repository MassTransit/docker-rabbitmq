FROM rabbitmq:3.8.3-management-alpine

RUN apk add curl

RUN curl https://dl.bintray.com/rabbitmq/community-plugins/3.8.x/rabbitmq_delayed_message_exchange/rabbitmq_delayed_message_exchange-20191008-3.8.x.zip > $RABBITMQ_HOME/plugins/rabbitmq_delayed_message_exchange-20191008-3.8.x.zip

RUN apk add unzip

RUN unzip $RABBITMQ_HOME/plugins/rabbitmq_delayed_message_exchange-20191008-3.8.x.zip -d $RABBITMQ_HOME/plugins

RUN rabbitmq-plugins enable --offline rabbitmq_delayed_message_exchange

RUN rabbitmq-plugins enable --offline rabbitmq_consistent_hash_exchange