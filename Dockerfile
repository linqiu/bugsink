# PostgreSQL-only Dockerfile for Bugsink (MySQL support removed).
#
# Configure your database/filestore/etc _outside_ of the current path
# to avoid copying them into the image.

ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim

ENV PYTHONUNBUFFERED=1

ENV PORT=8000

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/buildkit/pip \
    pip install "psycopg[binary]"

COPY requirements.txt /app/
RUN --mount=type=cache,target=/var/cache/buildkit/pip \
    pip install -r requirements.txt

COPY . /app/
COPY bugsink/conf_templates/docker.py.template bugsink_conf.py

# Git is needed by setuptools_scm to get the version from the git tag
RUN apt update && apt install -y git
RUN pip install -e .

RUN groupadd --gid 14237 bugsink \
 && useradd --uid 14237 --gid 14237 bugsink \
 && mkdir -p /data \
 && chown -R bugsink:bugsink /data

USER bugsink

HEALTHCHECK CMD python -c 'import requests; requests.get("http://localhost:8000/health/ready").raise_for_status()'

CMD [ "monofy", "bugsink-show-version", "&&", "bugsink-manage", "check", "--deploy", "--fail-level", "WARNING", "&&", "bugsink-manage", "migrate", "snappea", "--database=snappea", "&&", "bugsink-manage", "migrate", "&&", "bugsink-manage", "prestart", "&&", "gunicorn", "--config", "bugsink/gunicorn.docker.conf.py", "--bind=0.0.0.0:$PORT", "--access-logfile", "-", "bugsink.wsgi", "|||", "bugsink-runsnappea"]
