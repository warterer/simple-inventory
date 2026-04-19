FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --production

COPY . .

EXPOSE 8080

CMD node migrate.js --db_host=db --db_user=app --db_pass=12345678 --db_name=inventory_db && \
    node app.js --port=8080 --db_host=db --db_user=app --db_pass=12345678 --db_name=inventory_db