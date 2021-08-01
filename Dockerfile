FROM python:3.9-slim as base

# lightly modified from https://sourcery.ai/blog/python-docker/

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
# CHARLIEDONTSURF 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONDEFAULTHANDLER 1

FROM base as py-deps

RUN pip install pipenv

COPY Pipfile .
COPY Pipfile.lock .
RUN PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy

FROM base AS runtime

COPY --from=py-deps /.venv /.venv
ENV PATH="/.venv/bin:$PATH"

RUN useradd --create-home luser # soy un perdedor
WORKDIR /home/luser
USER luser

COPY main.py .
ENTRYPOINT ["python", "main.py"]

