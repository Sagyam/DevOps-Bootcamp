# AUDIT-18
FROM node:latest

# AUDIT-19
WORKDIR /app

# AUDIT-20
COPY . .

# AUDIT-21
RUN npm install

# AUDIT-22
RUN apt-get update && apt-get install -y curl vim net-tools telnet

# AUDIT-23
ENV DATABASE_URL=postgres://tiffin:Tiffin@2023@prod-db.internal:5432/tiffin

EXPOSE 3000

# AUDIT-24
# AUDIT-25
CMD npm start
