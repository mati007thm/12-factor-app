from locust import HttpUser, task, between
import random

default_headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.100 Safari/537.36'}

class EventsUser(HttpUser):
    wait_time = between(3, 5)  # Adjust the wait time between tasks as needed
    
    @task
    def event_lifecycle(self):
        user_id = random.random() + random.random() * random.random()

        for i in range(5):
            event_id = user_id * 1000 + i  # Create a unique event ID based on the user ID

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
            response = self.client.post('/newevent', json=data, headers=headers)

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} created successfully")
            else:
                print(f"Failed to create event {event_id}. Status code: {response.status_code}")
                continue  # Skip the rest of the loop for this event_id
            
            # Get the event
            response = self.client.get(f'/event/{event_id}')

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} retrieved successfully")
            else:
                print(f"Failed to retrieve event {event_id}. Status code: {response.status_code}")
                continue  # Skip the rest of the loop for this event_id

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
                continue  # Skip the rest of the loop for this event_id

            # Delete the event
            response = self.client.delete(f'/event/{event_id}')

            # Check if the request was successful
            if response.status_code == 200:
                print(f"Event {event_id} deleted successfully")
            else:
                print(f"Failed to delete event {event_id}. Status code: {response.status_code}")

        # Stop the user after completing the lifecycle
        # raise StopUser
