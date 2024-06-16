FROM python:3.11-alpine
COPY . /app
WORKDIR /app
# Install build dependencies
RUN apk add --no-cache gcc g++

RUN pip3 install -r /app/requirements.txt 

RUN apk del gcc g++ 

EXPOSE 5000
ENTRYPOINT ["python", "messages.py"]
