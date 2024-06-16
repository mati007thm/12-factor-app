import json
import os

import flask
from flask import request, jsonify
from flask_cors import CORS

from dapr.clients import DaprClient

from opentelemetry.sdk.resources import SERVICE_NAME, SERVICE_VERSION, Resource

from opentelemetry import metrics
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

# Service name is required for most backends
resource = Resource(attributes={
    SERVICE_NAME: "messages",
    SERVICE_VERSION: '0.1.0'
})

reader = PeriodicExportingMetricReader(
    OTLPMetricExporter()
)
meterProvider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(meterProvider)

meter = metrics.get_meter("messages.meter")

subscription_counter = meter.create_counter(
    "subscription.counter", unit="1", description="Counts the times the subscribe function is called"
)

app = flask.Flask(__name__)
CORS(app)

flask_port = os.getenv("FLASK_RUN_PORT", 5000)

# dapr calls this endpoint to register the subscriber configuration
# an alternative way would to be declare this inside a config yaml file
@app.route('/dapr/subscribe', methods=['GET'])
def subscribe():
    subscriptions = [{'pubsubname': 'pubsub',
                      'topic': 'events-topic',
                      'route': 'getmsg'}]
    return jsonify(subscriptions)

# subscriber acts as a listener for the topic events-topic
@app.route('/getmsg', methods=['POST'])
def subscriber():
    subscription_counter.add(1)
    print(request.json, flush=True)
    return json.dumps({'success':True}), 200, {'ContentType':'application/json'} 

if __name__ == "__main__":
    app.run(port=flask_port)
