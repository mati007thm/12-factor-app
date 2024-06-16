
#first stage - building golang artifact
FROM golang:1.20.12-alpine as builder
WORKDIR /src
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -o app .

# output container ...
FROM debian:buster-slim
COPY --from=builder /src/app /bin/app
EXPOSE 6000
CMD ["/bin/app"]