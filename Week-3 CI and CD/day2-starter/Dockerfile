# Day 2 Docker exercise: run the same tests inside a container so "works on my
# machine" stops being an argument. Notice we copy package files first and
# install *before* copying source — that is Docker layer caching, which you
# already met in the Docker week. CI will lean on this idea heavily on Day 3.
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "test"]
