FROM hashicorp/terraform:0.14.11
WORKDIR /data
RUN apk update && apk add ansible aws-cli py3-boto3 py3-botocore
ADD id_rsa /.ssh-key
RUN chmod 600 /.ssh-key
ENTRYPOINT ["terraform"]
CMD ["-help"]