
# create project directory
$ mkdir project

# go to project directory
$ cd project

# create db folder
$ mkdir postgres-db 

#create airflow folder
$ mkdir airflow

# go to db folder
$ cd postgres-db

# create source db folder
$ mkdir postgres-src
$ cd postgres-src

# pull a postgres docker image
$ sudo docker pull postgres

# create a dockerfile with following content
$ sudo nano Dockerfile 

FROM postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DB postgres_source
COPY postgres_source.sql /docker-entrypoint-initdb.d/

# create .sql file to create the source table with following content
$ sudo nano postgres_source.sql

create table public.sales
(
id int,
creation_date date,
sales_value numeric(10,2)
);

insert into public.sales (id, creation_date, sales_value) values (0,'2022-07-20', 100);
insert into public.sales (id, creation_date, sales_value) values (1,'2022-07-20', 200);
insert into public.sales (id, creation_date, sales_value) values (2,'2022-07-20', 400);

# build the postgres docker image
$ sudo docker build -t postgres-src ./

# start source db in a container
$ sudo docker run -d --name postgres-src-container -p 5432:5432 postgres-src

## similar steps to create target postgres database

# create target db folder
$ mkdir postgres-trgt
$ cd postgres-trgt

# pull a postgres docker image
$ sudo docker pull postgres

# create a dockerfile with following content
$ sudo nano Dockerfile 

FROM postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DB postgres_target
COPY postgres_target.sql /docker-entrypoint-initdb.d/

# create .sql file to create the source table with following content
$ sudo nano postgres_target.sql

create table public.sales
(
id int,
creation_date date,
sales_value numeric(10,2)
);

# build the postgres docker image
$ sudo docker build -t postgres-trgt ./

# start source db in a container
$ sudo docker run -d --name postgres-trgt-container -p 5433:5432 postgres-trgt


## go back to project home directory

# create folder for airflow
$ mkdir airflow
$ cd airflow

# get airlfow docker compose file
$ curl -LfO 'https://airflow.apache.org/docs/apache-airflow/2.3.3/docker-compose.yaml'

# create required folders
$ mkdir -p ./dags ./logs ./plugins

# create airflow dockerfile
$ sudo nano Dockerfile

FROM apache/airflow:2.2.3
ADD requirements.txt /usr/local/airflow/requirements.txt
RUN pip install --no-cache-dir -U pip setuptools wheel
RUN pip install --no-cache-dir -r /usr/local/airflow/requirements.txt

# initialize airflow database
$ sudo docker-compose -f airflow-docker-compose.yaml up airflow-init

# start airflow
$ sudo docker-compose -f airflow-docker-compose.yaml up -d


## now airflow web ui can be accessed at localhost:5884

# insstall required python packages
$ pip install -r requirements.txt

# go to dags folder
$ cd /dags

# create sample dag with following content -file location (/home/rafiul/project/airflow/dags/pipeline_dag.py)
$ sudo nano pipeline_dag.py



import os
from functools import wraps
import pandas as pd
from airflow.models import DAG
from airflow.utils.dates import days_ago
from airflow.operators.python import PythonOperator

from dotenv import dotenv_values
from sqlalchemy import create_engine, inspect

args = {"owner": "Airflow", "start_date": days_ago(1)}

dag = DAG(dag_id="pipeline_dag", default_args=args, schedule_interval=None)


def logger(func):
    from datetime import datetime, timezone

    @wraps(func)
    def wrapper(*args, **kwargs):
        called_at = datetime.now(timezone.utc)
        print(f">>> Running {func.__name__!r} function. Logged at {called_at}")
        to_execute = func(*args, **kwargs)
        print(f">>> Function: {func.__name__!r} executed. Logged at {called_at}")
        return to_execute

    return wrapper


CONFIG = dotenv_values(".env")
if not CONFIG:
    CONFIG = os.environ


source_table = "public.sales"
target_table = "public.sales"

src_user = CONFIG["POSTGRES_SRC_USER"]
src_pwd = CONFIG["POSTGRES_SRC_PASSWORD"]
src_host = CONFIG['POSTGRES_SRC_HOST']
src_port = CONFIG["POSTGRES_SRC_PORT"]
src_db = CONFIG["POSTGRES_SRC_DB"]

trgt_user = CONFIG["POSTGRES_TRGT_USER"]
trgt_pwd = CONFIG["POSTGRES_TRGT_PASSWORD"]
trgt_host = CONFIG['POSTGRES_TRGT_HOST']
trgt_port = CONFIG["POSTGRES_TRGT_PORT"]
trgt_db = CONFIG["POSTGRES_TRGT_DB"]




@logger
def connect_db(user, pwd, host, port, db):
    print("Connecting to DB")
    connection_uri = "postgresql+psycopg2://{}:{}@{}:{}/{}".format(
        user, pwd, host, port, db
    )

    engine = create_engine(connection_uri, pool_pre_ping=True)
    engine.connect()
    return engine


@logger
def extract(source_table):
    engine = connect_db(src_user, src_pwd, src_host, src_port, src_db)
    print(f"Reading data from {source_table}")
    df = pd.read_sql(f"SELECT * FROM {source_table}", engine)
    return df


@logger
def transform(df):
    # transformation
    print("Transforming data")
    df_transform = df.copy()
    df_transform["sales_value"] = df["sales_value"]*3
    return df_transform


@logger
def load_to_db(df, target_table):
    engine = connect_db(trgt_user, trgt_pwd, trgt_host, trgt_port, trgt_db)
    print(f"Loading dataframe to DB on table: {target_table}")
    df.to_sql(target_table, engine, if_exists="replace")
    engine.dispose()

@logger
def show_data():
    engine = connect_db(trgt_user, trgt_pwd, trgt_host, trgt_port, trgt_db)
    print("Showing data from target db:")
    df = pd.read_sql(f"SELECT * FROM {target_table}", engine)
    print(df)
    engine.dispose()

@logger
def etl():

    df = extract(source_table)
    print("Let's have a look how the source look like:")
    print(df)

    transformed_df = transform(df)
    #transformed_table = "public.dwd_sales_agg"

    load_to_db(transformed_df, target_table)




with dag:
    run_etl_task = PythonOperator(task_id="run_etl_task", python_callable=etl)
    show_data_from_target = PythonOperator(
        task_id="show_data_from_target", python_callable=show_data)

    run_etl_task >> show_data_from_target


## now this pipeline_dag.py will be available at web ui. This file will Extract data from source db, Transform and Load into Target database. 
