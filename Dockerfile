FROM apache/airflow:2.10.5

# Системные пакеты ставятся от root: MQTT-брокер + менеджер процессов.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        mosquitto \
        mosquitto-clients \
        supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY mosquitto.conf /etc/mosquitto/mosquitto.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Зависимости ставим от пользователя airflow — официальный образ хранит пакеты
# в домашней папке этого пользователя, туда же должен попасть и paho-mqtt.
USER airflow
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
COPY --chown=airflow:root dags/ /opt/airflow/dags/

# Заранее создаём пользователя admin/admin на этапе сборки. Тогда `airflow standalone`
# видит готового админа и не генерирует случайный пароль.
RUN airflow db migrate \
    && airflow users create \
        --username admin --password admin \
        --firstname Admin --lastname User \
        --role Admin --email admin@example.com

# Возвращаемся к root: supervisord стартует от root, чтобы запустить mosquitto и
# airflow каждый под своим непривилегированным пользователем (см. user= в конфиге).
USER root
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
