FROM python:3.12.11-alpine3.22

ARG FASTAPI_COMMON_COMMIT=9cf451311e0df2e4efed93531788120a5eeec60d

RUN apk add --no-cache curl git

WORKDIR /app

RUN pip install --upgrade pip setuptools && \
    pip install --no-cache-dir \
        "greenlet" \
        "jinja2" \
        "packaging" \
        "asyncpg" \
        "psycopg2-binary" \
        "psycopg[binary]" \
        "celery" \
        "gunicorn~=22.0.0" \
        "git+https://github.com/openg2p/openg2p-fastapi-common@${FASTAPI_COMMON_COMMIT}#subdirectory=openg2p-fastapi-common" \
        "git+https://github.com/openg2p/openg2p-fastapi-common@${FASTAPI_COMMON_COMMIT}#subdirectory=openg2p-fastapi-auth" \
        "git+https://github.com/openg2p/openg2p-fastapi-common@${FASTAPI_COMMON_COMMIT}#subdirectory=openg2p-fastapi-auth-models" \
        "git+https://github.com/openg2p/openg2p-fastapi-common@${FASTAPI_COMMON_COMMIT}#subdirectory=openg2p-fastapi-partner-auth"

COPY vendor/spar/models /src/models
COPY vendor/spar/mapper-core /src/mapper-core
COPY vendor/spar/bene-portal-api /src/bene-portal-api

RUN pip install --no-cache-dir --no-deps \
        /src/models \
        /src/mapper-core \
        /src/bene-portal-api

ENV PYTHONUNBUFFERED=1
WORKDIR /src/bene-portal-api

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
