#!/bin/bash

ENDPOINT="${ENDPOINT:-localhost}"
PORT="${PORT:-3000}"

echo Endpoint: $ENDPOINT
echo Port: $PORT

# Get event 1 (should fail)
echo 'Get event 1 (should fail)'
curl --location 'http://'$ENDPOINT':'$PORT'/event/1' | jq

# Create event 1
echo 'Create event 1'
curl --location 'http://'$ENDPOINT':'$PORT'/newevent' \
--header 'Content-Type: application/json' \
--data '{
    "data": {
        "name": "Uninstall Event",
        "date": "TBD",
        "id": "1"
    }
}' |jq

# Create event 1 again (should fail)
echo 'Create event 1 again (should fail)'
curl --location 'http://'$ENDPOINT':'$PORT'/newevent' \
--header 'Content-Type: application/json' \
--data '{
    "data": {
        "name": "Uninstall Event",
        "date": "TBD",
        "id": "1"
    }
}' | jq

# Get event 1
echo 'Get event 1'
curl --location 'http://'$ENDPOINT':'$PORT'/event/1' | jq

# Update event 1
echo 'Update event 1'
curl --location --request PUT 'http://'$ENDPOINT':'$PORT'/updateevent/1' \
--header 'Content-Type: application/json' \
--data '{
    "data": {
        "name": "Updated Event",
        "date": "TBD"
    }
}' | jq

# Get updated event 1
echo 'Get updated event 1'
curl --location 'http://'$ENDPOINT':'$PORT'/event/1' | jq

# Delete event 1
echo 'Delete event 1'
curl --location --request DELETE 'http://'$ENDPOINT':3000/event/1' | jq

# Delete event 1 again (should fail)
echo 'Delete event 1 again (should fail)'
curl --location --request DELETE 'http://'$ENDPOINT':'$PORT'/event/1' | jq