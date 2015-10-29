#!/bin/bash

# TODO: Support extracting arbitrary configuration values out of the
# environment. This could be done by pulling all env vars named SECOR_* and
# converting them to be dot-separated properties.

# For now this is hard-coded to use JSON parsing of messages, partitioned into
# S3 in time buckets.

# NOTE: if we need to only archive some topics, use this setting:
#   secor.kafka.topic_filter=.*

java -ea \
  -Daws.access.key=$AWS_ACCESS_KEY_ID \
  -Daws.secret.key=$AWS_SECRET_ACCESS_KEY\
  -Dzookeeper.quorum=$ZOOKEEPER \
  -Dsecor.s3.bucket=$S3_BUCKET \
  -Dsecor.max.file.size.bytes=$MAX_FILE_SIZE_BYTES \
  -Dsecor.max.file.age.seconds=$MAX_FILE_AGE_SECONDS \
  -Dkafka.seed.broker.host=$KAFKA_HOST \
  -Dkafka.seed.broker.port=$KAFKA_PORT \
  -Dsecor.compression.codec=org.apache.hadoop.io.compress.GzipCodec \
  -Dsecor.file.extension=.gz \
  -Dsecor.file.reader.writer.factory=com.pinterest.secor.io.impl.DelimitedTextFileReaderWriterFactory \
  -Dsecor.message.parser.class=com.pinterest.secor.parser.JsonMessageParser \
  -Dsecor.local.path=/tmp/secor_data/message_logs/partition \
  -Dlog4j.configuration=log4j.heroku.properties \
  -Dconfig=secor.prod.partition.properties \
  -cp target/classes:target/lib/* \
  com.pinterest.secor.main.ConsumerMain
