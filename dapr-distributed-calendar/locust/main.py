from locust import HttpUser, task, between

default_headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36'}

class EventsUser(HttpUser):
    wait_time = between(3, 5)  # Adjust the wait time between tasks as needed
    
    @task
    def event_lifecycle(self):
        for event_id in range(100, 105):
            # Create an event
            headers = {
                'Content-Type': 'application/json',
            }

            data = {
                "data": {
                    "name": f"Event {event_id}",
                    "date": "TBD",
                    "id": str(event_id)
                }
            }

            # Send the POST request to create an event
            response = self.client.post(f'/newevent', json=data, headers=headers)

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} created successfully")
            else:
                print(f"Failed to create event {event_id}. Status code: {response.status_code}")
            
            # Get the event
            response = self.client.get(f'/event/{event_id}')

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} retrieved successfully")
            else:
                print(f"Failed to retrieve event {event_id}. Status code: {response.status_code}")

            # Update the event
            updated_data = {
                "data": {
                    "name": f"Updated Event {event_id}",
                    "date": "2020-10-10"
                }
            }
            response = self.client.put(f'/updateevent/{event_id}', json=updated_data, headers=headers)
            
            # Check if the update was successful
            if response.status_code == 200:
                print(f"Event {event_id} updated successfully")
            else:
                print(f"Failed to update event {event_id}. Status code: {response.status_code}")

            # Delete the event
            response = self.client.delete(f'/event/{event_id}')

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} deleted successfully")
            else:
                print(f"Failed to delete event {event_id}. Status code: {response.status_code}")
