#!/usr/bin/python

import sys, os
from mlpipelinepy.mlpipeline import MLPipelineModel
from mlpipelinepy import SparkDataSources
from pyspark.sql import SparkSession, SQLContext
import dsx_core_utils, re, jaydebeapi
from sqlalchemy import *
from sqlalchemy.types import String, Boolean


# setup dsxr environmental vars from command line input
from dsx_ml.ml import dsxr_setup_environment
dsxr_setup_environment()

# define variables
args = {'target': '/datasets/scored-eval.csv', 'output_datasource_type': '', 'livyVersion': 'livyspark2', 'sysparm': '', 'output_type': 'Localfile', 'source': '/datasets/BreastCancerModelEval.csv', 'execution_type': 'DSX', 'remoteHostImage': '', 'remoteHost': ''}
input_data = os.getenv("DEF_DSX_DATASOURCE_INPUT_FILE", (os.getenv("DSX_PROJECT_DIR") + args.get("source")))
output_data = os.getenv("DEF_DSX_DATASOURCE_OUTPUT_FILE", (os.getenv("DSX_PROJECT_DIR") + args.get("target")))
model_path = os.getenv("DSX_PROJECT_DIR") + os.path.join("/models", os.getenv("DSX_MODEL_NAME","Breast Cancer Automated GBT"), os.getenv("DSX_MODEL_VERSION","1"),"model")

# read test dataframe (inputJson = "input.json")
spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext
testDF = SQLContext(sc).read.csv(input_data, header='true', inferSchema='true')

model = MLPipelineModel.load(model_path)

d = dict()
d['nodeADP'] = testDF
out = model.transform(SparkDataSources(d))

scoring_df = out[0].data_frame.toPandas()


# save output to csv
scoring_df.to_csv(output_data, encoding='utf-8')