FROM postgres:15.4

RUN apt-get update && apt-get install -y gettext && rm -rf /var/lib/apt/lists/*
