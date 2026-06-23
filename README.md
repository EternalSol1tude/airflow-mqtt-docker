# Airflow + Mosquitto в одном контейнере

Единый Docker-контейнер с Apache Airflow и MQTT-брокером Mosquitto. В Airflow есть
один DAG — `send_surname_to_mqtt`, который при запуске публикует фамилию кандидата
в MQTT.

## Состав

| Файл                 | Назначение                                                     |
|----------------------|----------------------------------------------------------------|
| `Dockerfile`         | Образ Airflow + Mosquitto, Supervisor и Python-зависимости      |
| `docker-compose.yml` | Запуск контейнера, проброс портов, фамилия кандидата            |
| `supervisord.conf`   | Запуск Mosquitto и Airflow как двух процессов в одном контейнере|
| `mosquitto.conf`     | Конфиг брокера (анонимный доступ, порт 1883)                    |
| `requirements.txt`   | Python-зависимости (`paho-mqtt`)                               |
| `dags/dag.py`        | Сам DAG                                                        |

## Архитектура

Контейнер по умолчанию рассчитан на один процесс, а здесь их два — брокер и Airflow.
Поэтому главным процессом (PID 1) выступает **supervisord**: он запускает Mosquitto
(от пользователя `mosquitto`) и `airflow standalone` (от пользователя `airflow`) и
перезапускает их при падении. `airflow standalone` одной командой поднимает
scheduler + webserver и использует встроенную SQLite в качестве базы метаданных
Airflow (где хранятся DAG-и, запуски, статусы задач).

Отсюда и два конфига: `supervisord.conf` описывает, какие два процесса поднимать и под
какими пользователями, а `mosquitto.conf` настраивает сам брокер (порт 1883, анонимный
доступ). Без supervisord два сервиса в одном контейнере держать не получится.

DAG берёт фамилию из переменной окружения `CANDIDATE_SURNAME` и через `paho-mqtt`
публикует сообщение в топик `airflow/candidate` на `localhost:1883` (брокер в том же
контейнере). Расписания нет (`schedule=None`) — запуск только вручную.

## Запуск

1. Укажите свою фамилию в `docker-compose.yml` (`CANDIDATE_SURNAME`).
2. Соберите и запустите:

   ```bash
   docker compose up --build
   ```

3. Откройте Airflow UI: http://localhost:8080. Логин и пароль — `admin` / `admin`.
4. Запустите (Trigger) DAG `send_surname_to_mqtt`.

## Проверка

Подпишитесь на топик **до** запуска DAG (брокер не хранит прошлые сообщения):

```bash
docker exec -it airflow-mqtt mosquitto_sub -h localhost -t airflow/candidate -v
```

После триггера в терминале появится:

```
airflow/candidate Candidate surname: <ваша фамилия>
```

Факт отправки также виден в логе задачи `publish_surname` в Airflow UI.
