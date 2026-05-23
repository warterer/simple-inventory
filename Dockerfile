FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --production

COPY . .

EXPOSE 8080

ENV DB_HOST=db \
    DB_USER=app \
    DB_PASS=changeme \
    DB_NAME=inventory_db \
    PORT=8080

CMD ["sh", "-c", \
  "node migrate.js \
    --db_host=$DB_HOST \
    --db_user=$DB_USER \
    --db_pass=$DB_PASS \
    --db_name=$DB_NAME \
  && node app.js \
    --port=$PORT \
    --db_host=$DB_HOST \
    --db_user=$DB_USER \
    --db_pass=$DB_PASS \
    --db_name=$DB_NAME"]