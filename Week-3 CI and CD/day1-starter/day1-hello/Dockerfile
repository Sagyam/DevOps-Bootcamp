# Day 1 keeps Docker simple: one stage, copy the script, run it.
# You already know how to build and run this locally:
#   docker build -t day1-hello .
#   docker run --rm -e GREET_NAME=Docker day1-hello
FROM node:22-alpine
WORKDIR /app
COPY greet.js .
CMD ["node", "greet.js"]
