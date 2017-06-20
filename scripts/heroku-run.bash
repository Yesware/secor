#!/bin/bash

# TODO: Support extracting arbitrary configuration values out of the
# environment. This could be done by pulling all env vars named SECOR_* and
# converting them to be dot-separated properties.

# For now this is hard-coded to use JSON parsing of messages, partitioned into
# S3 in time buckets.

# NOTE: if we need to only archive some topics, use this setting:
#   secor.kafka.topic_filter=.*

# Convert Heroku env vars for Kafka into ones compatible with secor. These come in in the format of:
# zookeeper://10.1.54.249:2181,zookeeper://10.1.104.244:2181,zookeeper://10.1.66.173:2181
# and
# kafka://10.1.16.157:6667,kafka://10.1.0.165:6667,kafka://10.1.50.155:6667
ZOOKEEPER="${HEROKU_KAFKA_ZOOKEEPER_URL//zookeeper:\/\/}"
KAFKA="${HEROKU_KAFKA_PLAINTEXT_URL//kafka:\/\//}"
ONE_KAFKA="${KAFKA%%,*}"
KAFKA_HOST="${ONE_KAFKA%:*}"
KAFKA_PORT="${ONE_KAFKA#*:}"

S3KEY=$LOG_AWS_KEY
S3SECRET=$LOG_AWS_SECRET

function putS3
{
  path=$1
  file=$2
  aws_path=$3
  bucket='barry-allen-crash-files'
  date=$(date +"%a, %d %b %Y %T %z")
  acl="x-amz-acl:public-read"
  content_type='text/plain'
  string="PUT\n\n$content_type\n$date\n$acl\n/$bucket$aws_path$file"
  signature=$(echo -en "${string}" | openssl sha1 -hmac "${S3SECRET}" -binary | base64)
  fsize=$(stat -c '%s' $file)
  curl --verbose -X PUT -T "$path./$file" \
    -H "Host: $bucket.s3.amazonaws.com" \
    -H "Date: $date" \
    -H "Content-Type: $content_type" \
    -H "Content-Length: $fsize" \
    -H "$acl" \
    -H "Authorization: AWS ${S3KEY}:$signature" \
    "https://$bucket.s3.amazonaws.com$aws_path$file"
}

java -ea \
  -Xms2400m -Xmx2400m
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


for file in "$path"./hs*.log; do
	putS3 "$path" "${file##*/}" "/"
done
