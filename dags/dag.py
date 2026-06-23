"""DAG, который при ручном запуске публикует фамилию кандидата в MQTT."""

import os
from datetime import datetime

import paho.mqtt.publish as publish
from airflow import DAG
from airflow.operators.python import PythonOperator

CANDIDATE_SURNAME = os.environ.get("CANDIDATE_SURNAME", "Shaymukhametov")
MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_TOPIC = os.environ.get("MQTT_TOPIC", "airflow/candidate")


def publish_surname():
    message = f"Candidate surname: {CANDIDATE_SURNAME}"
    publish.single(MQTT_TOPIC, payload=message, hostname=MQTT_HOST, port=MQTT_PORT)
    print(f"Sent to MQTT {MQTT_HOST}:{MQTT_PORT} topic '{MQTT_TOPIC}': {message}")


with DAG(
    dag_id="send_surname_to_mqtt",
    description="Публикует фамилию кандидата в MQTT",
    start_date=datetime(2024, 1, 1),
    schedule=None,  # только ручной запуск
    catchup=False,
    tags=["mqtt"],
) as dag:
    PythonOperator(task_id="publish_surname", python_callable=publish_surname)
