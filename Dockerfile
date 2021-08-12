FROM <base>

ARG CONNECTOR_VERSION=latest
ENV CONNECTOR_VERSION=${CONNECTOR_VERSION}

CMD ["<your model>", "<args>", "..."]
